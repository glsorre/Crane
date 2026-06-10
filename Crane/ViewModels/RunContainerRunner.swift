//
//  RunContainerRunner.swift
//  Crane
//
//  Store-scoped coordinator for the "Run Container" pipeline. Mirrors
//  `BuildViewModel`: it owns the run `status` so a placeholder row in
//  the containers list can keep showing progress and errors after the
//  run sheet has dismissed itself immediately. The actual configuration
//  is built by `RunContainerViewModel` and handed in here as a value.
//

import ContainerAPIClient
import ContainerResource
import Containerization
import Foundation
import Observation
import os.log

enum RunStatus: Equatable {
    case idle
    case running(String)
    case success(String)
    case failed(String, String)

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    /// Name of the container whose run is currently in-flight or last finished.
    /// `nil` only when fully idle.
    var name: String? {
        switch self {
        case .idle: return nil
        case .running(let name), .success(let name), .failed(let name, _):
            return name
        }
    }
}

@MainActor
@Observable
final class RunContainerRunner {
    /// Drives the placeholder row in the containers list.
    var status: RunStatus = .idle

    /// Auto-clear delay for `.success` so the background row disappears
    /// shortly after the new container lands in the list (the list poll
    /// refreshes within ~1s on its own).
    private static let successBannerDismissDelay: Duration = .seconds(2)

    /// Spawns a detached task that runs the create + bootstrap + start +
    /// early-exit-watch pipeline. The dialog has already closed by the
    /// time this method returns; the caller is expected to set
    /// `isPresented = false` right after calling.
    func start(configuration: ContainerConfiguration, name: String, autoRemove: Bool) {
        status = .running(name)
        let capturedName = name
        Task { [weak self] in
            await self?.runPipeline(
                configuration: configuration,
                name: capturedName,
                autoRemove: autoRemove
            )
        }
    }

    /// User-dismissable terminal status. Clears `.failed` and `.success`
    /// back to `.idle`. Mirrors `BuildViewModel.dismissTerminalStatus()`.
    func dismissTerminalStatus() {
        switch status {
        case .failed, .success:
            status = .idle
        default:
            return
        }
    }

    /// Synchronous failure path used when `RunContainerViewModel` cannot
    /// even build a `ContainerConfiguration` (form validation/image
    /// resolution failed at hand-off time). Posts a notification so the
    /// user gets the same out-of-app signal as the in-flight failures.
    func recordImmediateFailure(name: String, message: String) {
        status = .failed(name, message)
        NotificationsManager.post(
            .runFailed,
            title: String(localized: "notifyRunFailedTitle"),
            body: String(localized: "notifyRunFailedBody \(name) \(message)")
        )
    }

    // MARK: - Pipeline

    private func runPipeline(
        configuration: ContainerConfiguration,
        name: String,
        autoRemove: Bool
    ) async {
        let containerClient = ContainerClient()
        let containerName = name
        let shouldAutoRemove = autoRemove

        do {
            try await containerClient.create(
                configuration: configuration,
                options: ContainerCreateOptions(autoRemove: false),
                kernel: try await ClientKernel.getDefaultKernel(for: .current)
            )
        } catch {
            Log.run.error("create failed for \(containerName): \(error.localizedDescription, privacy: .public)")
            status = .failed(containerName, error.localizedDescription)
            NotificationsManager.post(
                .runFailed,
                title: String(localized: "notifyRunFailedTitle"),
                body: String(localized: "notifyRunFailedBody \(containerName) \(error.localizedDescription)")
            )
            return
        }

        if !shouldAutoRemove {
            AppSettings.addPersistentContainerID(containerName)
        }

        do {
            try await withTimeout {
                let io = try ProcessIO.create(tty: true, interactive: false, detach: true)
                defer {
                    _ = try? io.close()
                }
                let process = try await containerClient.bootstrap(id: containerName, stdio: io.stdio)
                try await process.start()
            }
        } catch {
            Log.run.error("bootstrap/start failed for \(containerName): \(error.localizedDescription, privacy: .public)")
            AppSettings.removePersistentContainerID(containerName)
            CraneMutationBus.postContainerMutated()
            status = .failed(containerName, error.localizedDescription)
            NotificationsManager.post(
                .runFailed,
                title: String(localized: "notifyRunFailedTitle"),
                body: String(localized: "notifyRunFailedBody \(containerName) \(error.localizedDescription)")
            )
            return
        }

        let exitedDuringWatch = await Self.watchForEarlyExit(
            client: containerClient,
            id: containerName
        )

        if exitedDuringWatch {
            let tail = await Self.fetchLogTail(
                client: containerClient,
                id: containerName,
                maxLines: 40
            )
            AppSettings.removePersistentContainerID(containerName)
            try? await containerClient.delete(id: containerName)
            CraneMutationBus.postContainerMutated()

            let baseMessage = String(
                localized: "runContainerExitedEarly",
                defaultValue: "Container exited shortly after starting. Check the command, arguments, and environment."
            )
            let combined = tail.isEmpty ? baseMessage : "\(baseMessage)\n\n\(tail)"
            Log.run.error("container \(containerName) exited within watch window")
            status = .failed(containerName, combined)
            NotificationsManager.post(
                .runFailed,
                title: String(localized: "notifyRunFailedTitle"),
                body: String(localized: "notifyRunFailedBody \(containerName) \(combined)")
            )
            return
        }

        if shouldAutoRemove {
            Self.scheduleAutoRemove(client: containerClient, id: containerName)
        }

        CraneMutationBus.postContainerMutated()
        status = .success(containerName)
        scheduleSuccessBannerDismiss()
    }

    private func scheduleSuccessBannerDismiss() {
        Task { [weak self] in
            try? await Task.sleep(for: Self.successBannerDismissDelay)
            guard let self else { return }
            if case .success = self.status {
                self.status = .idle
            }
        }
    }

    nonisolated private static let earlyExitWatchDuration: Duration = .seconds(2)
    nonisolated private static let earlyExitWatchCadence: Duration = .milliseconds(250)
    nonisolated private static let autoRemovePollCadence: Duration = .seconds(1)

    nonisolated private static func watchForEarlyExit(
        client: ContainerClient,
        id: String
    ) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: earlyExitWatchDuration)
        while ContinuousClock.now < deadline {
            try? await Task.sleep(for: earlyExitWatchCadence)
            guard let snapshots = try? await client.list() else { continue }
            guard let snapshot = snapshots.first(where: { $0.id == id }) else {
                return true
            }
            if snapshot.status != .running {
                return true
            }
        }
        return false
    }

    nonisolated private static func fetchLogTail(
        client: ContainerClient,
        id: String,
        maxLines: Int
    ) async -> String {
        do {
            let handles = try await client.logs(id: id)
            var lines: [String] = []
            let trimWhenAbove = max(maxLines * 4, maxLines + 1)
            let trimDownTo = max(maxLines * 2, maxLines)
            for handle in handles {
                guard let reader = StreamReader(fileHandle: handle) else { continue }
                while let line = reader.nextLine() {
                    lines.append(line)
                    if lines.count > trimWhenAbove {
                        lines.removeFirst(lines.count - trimDownTo)
                    }
                }
            }
            if lines.count > maxLines {
                lines = Array(lines.suffix(maxLines))
            }
            return lines.joined(separator: "\n")
        } catch {
            Log.run.error("fetch log tail failed for \(id): \(error.localizedDescription, privacy: .public)")
            return ""
        }
    }

    nonisolated private static func scheduleAutoRemove(client: ContainerClient, id: String) {
        Task.detached {
            while !Task.isCancelled {
                try? await Task.sleep(for: autoRemovePollCadence)
                guard let snapshots = try? await client.list() else { continue }
                guard let snapshot = snapshots.first(where: { $0.id == id }) else {
                    CraneMutationBus.postContainerMutated()
                    return
                }
                if snapshot.status == .running || snapshot.status == .stopping {
                    continue
                }
                try? await client.delete(id: id)
                CraneMutationBus.postContainerMutated()
                return
            }
        }
    }
}
