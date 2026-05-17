//
//  DetailsViewModel.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 06/12/25.
//

import ContainerAPIClient
import ContainerResource
import ContainerizationOCI
import Foundation
import Observation
import SwiftUI
import os.log

enum DetailsTab: String, CaseIterable {
    case information
    case logs
}

struct ContainerLogLine: Identifiable {
    let id: Int
    let message: String
}

@Observable
class ContainerLogStream: Identifiable {
    var logs: [ContainerLogLine] = []
    var userScrolled: Bool = false
    var followLogs: Bool = true
    var nextLogId: Int = 0
    var forceScroll: Bool = false
}

@Observable
class ContainerMetrics {
    var memoryUsageBytes: UInt64?
    var memoryLimitBytes: UInt64?
    var cpuUsageUsec: UInt64?
    var networkRxBytes: UInt64?
    var networkTxBytes: UInt64?
    var blockReadBytes: UInt64?
    var blockWriteBytes: UInt64?
    var numProcesses: UInt64?
    var cpuPercent: Double?
    var isAvailable: Bool = false
}

@Observable
class DetailsViewModel {
    var container: Container
    var currentHandle: Int = 0
    var selectedTab: DetailsTab = .information
    var metrics = ContainerMetrics()

    var logHandles: [Int: ContainerLogStream] = [:]

    var streamingTask: Task<Void, Never>? = nil
    var metricsTask: Task<Void, Never>? = nil

    init(container: Container) {
        self.container = container
        self.start(handleIndex: self.currentHandle)
        self.startMetricsPolling()
    }

    deinit {
        self.stop()
        self.metricsTask?.cancel()
    }

    func bootstrap() async {
        do {
            let handlesCount = try await container.logs().count

            for handleIndex in 0..<handlesCount {
                if self.logHandles[handleIndex] == nil {
                    self.logHandles[handleIndex] = ContainerLogStream()
                }
            }
        } catch {
            AppViewModel.shared.showError(.logStreamFailed(error.localizedDescription))
        }
    }

    func start(handleIndex: Int) {
        self.streamingTask?.cancel()

        self.streamingTask = Task {
            do {
                if self.logHandles[handleIndex] == nil {
                    self.logHandles[handleIndex] = ContainerLogStream()
                }
                guard let logMetadata = self.logHandles[handleIndex] else { return }

                let fileHandle = try await container.logs()[handleIndex]

                // Bulk-read existing content
                if let reader = StreamReader(fileHandle: fileHandle) {
                    while let line = reader.nextLine() {
                        logMetadata.logs.append(ContainerLogLine(id: logMetadata.nextLogId, message: line))
                        logMetadata.nextLogId += 1
                    }
                    reader.atEof = false
                }

                if logMetadata.followLogs && !logMetadata.userScrolled {
                    logMetadata.forceScroll = true
                }

                // Stream new lines as they arrive
                for await line in streamLogFile(fileHandle: fileHandle) {
                    if Task.isCancelled { break }
                    logMetadata.logs.append(ContainerLogLine(id: logMetadata.nextLogId, message: line))
                    logMetadata.nextLogId += 1

                    if logMetadata.followLogs && !logMetadata.userScrolled {
                        logMetadata.forceScroll = true
                    }
                }
            } catch {
                AppViewModel.shared.showError(.logStreamFailed(error.localizedDescription))
            }
        }
    }

    func stop() {
        self.streamingTask?.cancel()
    }

    func startContainer() async {
        do {
            try await container.start()
        } catch {
            AppViewModel.shared.showError(.containerStartFailed(error.localizedDescription))
        }
    }

    func stopContainer() async {
        do {
            try await container.stop()
        } catch {
            AppViewModel.shared.showError(.containerStopFailed(error.localizedDescription))
        }
    }

    func restartContainer() async {
        do {
            try await container.restart()
        } catch {
            AppViewModel.shared.showError(.containerRestartFailed(error.localizedDescription))
        }
    }

    func openShellInTerminal() {
        do {
            try ContainerShellLauncher.openInteractiveShell(containerID: container.id)
        } catch {
            AppViewModel.shared.showError(.containerShellFailed(error.localizedDescription))
        }
    }

    func removeContainer() async {
        await ContainersStore.shared.removeContainer(id: container.id)
        AppViewModel.shared.showContainersList()
    }

    func getHandleName(handleIndex: Int) -> String {
        Self.handleName(handleIndex: handleIndex, handleCount: logHandles.count)
    }

    static func handleName(handleIndex: Int, handleCount: Int) -> String {
        if handleIndex < handleCount - 1 {
            if handleIndex == 0 {
                return "Process"
            }
            return "Process \(handleIndex + 1)"
        }
        return "System"
    }

    func startMetricsPolling() {
        metricsTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.container.snapshot.status == .running else {
                    self?.metrics.isAvailable = false
                    try? await Task.sleep(for: .seconds(2))
                    continue
                }
                do {
                    let sample1 = try await self.container.stats()
                    try await Task.sleep(for: .seconds(2))
                    if Task.isCancelled { break }
                    let sample2 = try await self.container.stats()

                    self.metrics.memoryUsageBytes = sample2.memoryUsageBytes
                    self.metrics.memoryLimitBytes = sample2.memoryLimitBytes
                    self.metrics.networkRxBytes = sample2.networkRxBytes
                    self.metrics.networkTxBytes = sample2.networkTxBytes
                    self.metrics.blockReadBytes = sample2.blockReadBytes
                    self.metrics.blockWriteBytes = sample2.blockWriteBytes
                    self.metrics.numProcesses = sample2.numProcesses
                    self.metrics.cpuUsageUsec = sample2.cpuUsageUsec

                    if let cpu1 = sample1.cpuUsageUsec, let cpu2 = sample2.cpuUsageUsec, cpu2 >= cpu1 {
                        let deltaUsec = Double(cpu2 - cpu1)
                        self.metrics.cpuPercent = deltaUsec / 2_000_000 * 100
                    } else {
                        self.metrics.cpuPercent = nil
                    }

                    self.metrics.isAvailable = true
                } catch {
                    self.metrics.isAvailable = false
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        }
    }

    static func formatBytes(_ bytes: UInt64) -> String {
        let gib = Double(bytes) / (1024 * 1024 * 1024)
        if gib >= 1 {
            return String(format: "%.1f GiB", gib)
        }
        let mib = Double(bytes) / (1024 * 1024)
        if mib >= 1 {
            return String(format: "%.1f MiB", mib)
        }
        let kib = Double(bytes) / 1024
        return String(format: "%.1f KiB", kib)
    }
}
