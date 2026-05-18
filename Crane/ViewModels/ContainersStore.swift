//
//  ContainersStore.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 08/12/25.
//

import ContainerAPIClient
import ContainerResource
import ContainerizationOCI
import Foundation
import Observation
import SwiftUI
import os.log

@Observable
class Container: Identifiable, Hashable {
    private static let client = ContainerClient()

    static func == (lhs: Container, rhs: Container) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var id: String
    var snapshot: ContainerSnapshot
    var transiting: Bool
    var isExited: Bool = false
    var autoRemove: Bool = true

    init(snapshot: ContainerSnapshot) {
        self.id = snapshot.id
        self.snapshot = snapshot
        self.transiting = false
        self.autoRemove = !AppSettings.persistentContainerIDs.contains(snapshot.id)
    }

    func update(snapshot: ContainerSnapshot) {
        self.snapshot = snapshot
    }

    func start() async throws {
        self.transiting = true
        let fileManager = FileManager.default
        if self.snapshot.configuration.mounts.contains(where: {
            $0.isVolume && !fileManager.fileExists(atPath: $0.source)
        }) {
            self.transiting = false
            throw NSError(
                domain: "Crane",
                code: 1001,
                userInfo: [
                    NSLocalizedDescriptionKey: String(localized: "containerStartMissingVolumePath")
                ]
            )
        }

        do {
            try await withTimeout {
                let io = try ProcessIO.create(tty: true, interactive: false, detach: true)
                defer {
                    _ = try? io.close()
                }
                let process = try await Self.client.bootstrap(id: self.id, stdio: io.stdio)
                try await process.start()
            }
        } catch {
            self.transiting = false
            Log.containers.error("start failed for \(self.id): \(error.localizedDescription, privacy: .public)")
            throw error
        }
        try? await Task.sleep(for: .milliseconds(500))
        self.transiting = false
        CraneMutationBus.postContainerMutated()
    }

    func stop() async throws {
        self.transiting = true

        do {
            try await withTimeout {
                try await Self.client.stop(id: self.id)
            }
        } catch {
            self.transiting = false
            Log.containers.error("stop failed for \(self.id): \(error.localizedDescription, privacy: .public)")
            throw error
        }

        try? await Task.sleep(for: .milliseconds(500))
        self.transiting = false
        CraneMutationBus.postContainerMutated()
    }

    func restart() async throws {
        try await stop()
        try await start()
    }

    func remove() async throws {
        self.transiting = true

        do {
            try await withTimeout {
                try await Self.client.delete(id: self.id)
            }
        } catch {
            self.transiting = false
            Log.containers.error("remove failed for \(self.id): \(error.localizedDescription, privacy: .public)")
            throw error
        }

        CraneMutationBus.postContainerMutated()
    }

    func logs() async throws -> [FileHandle] {
        try await Self.client.logs(id: id)
    }

    func dial(_ port: UInt32) async throws -> FileHandle {
        try await Self.client.dial(id: id, port: port)
    }

    func stats() async throws -> ContainerStats {
        try await Self.client.stats(id: id)
    }
}

@Observable
class ContainersStore {
    private let client = ContainerClient()
    private let onError: @MainActor (CraneError) -> Void
    private let tracker: ConnectionHealthTracker?

    var containers: Set<Container> = []
    var containersTask: Task<Void, Never>?
    var resetPolling: (() -> Void)?

    var searchText: String = ""

    var sortedFilteredContainers: [Container] {
        containers
            .sorted { $0.id < $1.id }
            .filter { self.searchText.isEmpty || ($0.id.contains(self.searchText)) }
    }

    var images: [ImageDescription] {
        containers.compactMap { $0.snapshot.configuration.image }
    }

    var containersForImage: [String: [Container]] {
        Dictionary(grouping: containers) { $0.snapshot.configuration.image.reference }
    }

    var networks: [AttachmentConfiguration] {
        containers.flatMap { $0.snapshot.configuration.networks }
    }

    var containersForNetwork: [String: [Container]] {
        Dictionary(
            grouping: containers.flatMap { container in
                container.snapshot.configuration.networks.map { ($0, container) }
            }, by: { $0.0.network }
        ).mapValues { $0.map(\.1) }
    }

    var containersForVolume: [String: [Container]] {
        Dictionary(
            grouping: containers.flatMap { container in
                container.snapshot.configuration.mounts
                    .filter { $0.isVolume }
                    .compactMap { mount -> (String, Container)? in
                        guard let name = mount.volumeName else { return nil }
                        return (name, container)
                    }
            }, by: { $0.0 }
        ).mapValues { $0.map(\.1) }
    }

    init(
        onError: @escaping @MainActor (CraneError) -> Void = { _ in },
        tracker: ConnectionHealthTracker? = nil
    ) {
        self.onError = onError
        self.tracker = tracker
    }

    deinit {
        self.stop()
    }

    func stop() {
        self.containersTask?.cancel()
    }

    func start() {
        guard AppSettings.autoRefresh else { return }
        let tracker = self.tracker
        let (task, reset) = startAdaptivePolling(
            baseInterval: { AppSettings.refreshInterval },
            maxInterval: { AppSettings.maxPollingInterval },
            isVisible: { PollingVisibility.isVisible(for: .containers) },
            onError: { error in
                Task { @MainActor in
                    tracker?.recordFailure(resource: .containers, error: error)
                }
            },
            work: {
                try await self.collectWithChangeDetection()
            }
        )
        self.containersTask = task
        self.resetPolling = reset
    }

    @discardableResult
    func collect() async throws -> Bool {
        try await collectWithChangeDetection()
    }

    private func collectWithChangeDetection() async throws -> Bool {
        let previousIDs = Set(containers.map { $0.id })
        let previousCount = containers.count
        let persistentContainerIDs = AppSettings.persistentContainerIDs

        let currentSnapshots = try await client.list()
        var currentContainersSet: Set<Container> = []

        for snapshot in currentSnapshots {
            let newContainer = Container(snapshot: snapshot)
            currentContainersSet.insert(newContainer)
            if let container = containers.first(where: { $0.id == newContainer.id }) {
                container.update(snapshot: snapshot)
                container.isExited = false
                container.autoRemove = !persistentContainerIDs.contains(container.id)
            }
            containers.insert(newContainer)
        }

        let exitedContainers = containers.subtracting(currentContainersSet)
        exitedContainers.forEach { container in
            let shouldPersist = persistentContainerIDs.contains(container.id)
            container.autoRemove = !shouldPersist
            if shouldPersist {
                container.isExited = true
                container.transiting = false
            } else {
                containers.remove(container)
            }
        }

        let newIDs = Set(containers.map { $0.id })
        let tracker = self.tracker
        Task { @MainActor in
            tracker?.recordSuccess()
        }
        return previousIDs != newIDs || previousCount != containers.count
    }

    func reset() async throws {
        containers.removeAll()
        try await self.collect()
    }

    func startContainer(id: String) async {
        guard let container = containers.first(where: { $0.id == id }) else { return }
        do {
            try await container.start()
        } catch {
            Log.containers.error("startContainer(\(id)) failed: \(error.localizedDescription, privacy: .public)")
            await onError(.containerStartFailed(underlying: error))
        }
    }

    func stopContainer(id: String) async {
        guard let container = containers.first(where: { $0.id == id }) else { return }
        do {
            try await container.stop()
        } catch {
            Log.containers.error("stopContainer(\(id)) failed: \(error.localizedDescription, privacy: .public)")
            await onError(.containerStopFailed(underlying: error))
        }
    }

    func restartContainer(id: String) async {
        guard let container = containers.first(where: { $0.id == id }) else { return }
        do {
            try await container.restart()
        } catch {
            Log.containers.error("restartContainer(\(id)) failed: \(error.localizedDescription, privacy: .public)")
            await onError(.containerRestartFailed(underlying: error))
        }
    }

    var hasExitedContainers: Bool {
        containers.contains { $0.isExited }
    }

    func pruneExitedContainers() async {
        let exited = containers.filter { $0.isExited }
        for container in exited {
            await removeContainer(id: container.id)
        }
    }

    func removeContainer(id: String) async {
        guard let container = containers.first(where: { $0.id == id }) else { return }
        if container.isExited {
            containers.remove(container)
            AppSettings.removePersistentContainerID(id)
            return
        }
        do {
            try await container.remove()
            AppSettings.removePersistentContainerID(id)
            container.autoRemove = true
            container.isExited = false
            container.transiting = false
            containers.remove(container)
        } catch {
            Log.containers.error("removeContainer(\(id)) failed: \(error.localizedDescription, privacy: .public)")
            await onError(.containerRemoveFailed(underlying: error))
        }
    }
}
