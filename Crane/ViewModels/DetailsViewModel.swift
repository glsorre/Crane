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

enum LogLevel: String, CaseIterable, Hashable {
    case fatal = "FATAL"
    case error = "ERROR"
    case warn  = "WARN"
    case info  = "INFO"
    case debug = "DEBUG"
    case trace = "TRACE"
}

struct ContainerLogLine: Identifiable {
    let id: Int
    let message: String
    let arrivedAt: Date
    let level: LogLevel?

    init(id: Int, message: String, arrivedAt: Date = Date()) {
        self.id = id
        self.message = message
        self.arrivedAt = arrivedAt
        self.level = LogLineFormatter.detectLevel(in: message)
    }
}

@Observable
class ContainerLogStream: Identifiable {
    static let maxLines: Int = 10_000
    static let evictionBatch: Int = 500

    var logs: [ContainerLogLine] = []
    var userScrolled: Bool = false
    var followLogs: Bool = true
    var nextLogId: Int = 0
    var forceScroll: Bool = false
    var droppedCount: Int = 0

    // Filter / search / display state
    var searchQuery: String = ""
    var searchIsRegex: Bool = false
    var searchCaseSensitive: Bool = false
    var levelFilter: Set<LogLevel> = []
    var showTimestamps: Bool = false
    var showLineNumbers: Bool = false
    var fontSize: CGFloat = 12
    var matchCount: Int = 0
    var currentMatchIndex: Int = 0

    func append(message: String) {
        let line = ContainerLogLine(id: nextLogId, message: message)
        nextLogId &+= 1
        logs.append(line)
        if logs.count >= Self.maxLines + Self.evictionBatch {
            let evict = Self.evictionBatch
            logs.removeFirst(evict)
            droppedCount &+= evict
        }
    }

    func clear() {
        logs.removeAll()
        droppedCount = 0
        matchCount = 0
        currentMatchIndex = 0
    }
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
    private let stores: CraneStores

    var logHandles: [Int: ContainerLogStream] = [:]

    var streamingTask: Task<Void, Never>? = nil
    var metricsTask: Task<Void, Never>? = nil
    private var metricsResetToken: ObjectIdentifier?
    private var previousCPUSampleUsec: UInt64?
    private var previousCPUSampleTime: ContinuousClock.Instant?

    init(container: Container, stores: CraneStores) {
        self.container = container
        self.stores = stores
        self.start(handleIndex: self.currentHandle)
        self.startMetricsPolling()
    }

    deinit {
        self.streamingTask?.cancel()
        self.metricsTask?.cancel()
        if let token = metricsResetToken {
            let refresh = stores.refresh
            Task { @MainActor [token, refresh] in
                refresh.unregisterReset(token: token)
            }
        }
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
            Log.logs.error("bootstrap log handles failed for \(self.container.id): \(error.localizedDescription, privacy: .public)")
            await stores.app.showError(.logStreamFailed(underlying: error))
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

                if logMetadata.logs.isEmpty {
                    // First-time ingest: read existing on-disk content.
                    if let reader = StreamReader(fileHandle: fileHandle) {
                        while let line = reader.nextLine() {
                            logMetadata.append(message: line)
                        }
                        reader.atEof = false
                    }
                } else {
                    // Already initialized: skip to end so streamLogFile doesn't re-emit lines we have.
                    try? fileHandle.seekToEnd()
                }

                if logMetadata.followLogs && !logMetadata.userScrolled {
                    logMetadata.forceScroll = true
                }

                // Stream new lines as they arrive
                for await line in streamLogFile(fileHandle: fileHandle) {
                    if Task.isCancelled { break }
                    logMetadata.append(message: line)

                    if logMetadata.followLogs && !logMetadata.userScrolled {
                        logMetadata.forceScroll = true
                    }
                }
            } catch {
                Log.logs.error("stream handle \(handleIndex) failed for \(self.container.id): \(error.localizedDescription, privacy: .public)")
                await stores.app.showError(.logStreamFailed(underlying: error))
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
            Log.details.error("startContainer failed for \(self.container.id): \(error.localizedDescription, privacy: .public)")
            stores.app.showError(.containerStartFailed(underlying: error))
        }
    }

    func stopContainer() async {
        do {
            try await container.stop()
        } catch {
            Log.details.error("stopContainer failed for \(self.container.id): \(error.localizedDescription, privacy: .public)")
            stores.app.showError(.containerStopFailed(underlying: error))
        }
    }

    func restartContainer() async {
        do {
            try await container.restart()
        } catch {
            Log.details.error("restartContainer failed for \(self.container.id): \(error.localizedDescription, privacy: .public)")
            stores.app.showError(.containerRestartFailed(underlying: error))
        }
    }

    func openShellInTerminal() {
        do {
            try ContainerShellLauncher.openInteractiveShell(containerID: container.id)
        } catch {
            Log.details.error("openShellInTerminal failed for \(self.container.id): \(error.localizedDescription, privacy: .public)")
            stores.app.showError(.containerShellFailed(underlying: error))
        }
    }

    func removeContainer() async {
        await stores.containers.removeContainer(id: container.id)
        stores.app.showContainersList()
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
        let polling = startAdaptivePolling(
            baseInterval: { AppSettings.refreshInterval },
            maxInterval: { AppSettings.maxPollingInterval },
            isVisible: { PollingVisibility.isVisible(for: .containers) },
            work: { [weak self] in
                guard let self else { return false }
                return try await self.collectMetricsSample()
            }
        )
        metricsTask = polling.task

        let token = ObjectIdentifier(self)
        metricsResetToken = token
        let reset = polling.reset
        let refresh = stores.refresh
        Task { @MainActor in
            refresh.registerReset(token: token, reset: reset)
        }
    }

    private func collectMetricsSample() async throws -> Bool {
        guard container.snapshot.status == .running else {
            await MainActor.run {
                self.metrics.isAvailable = false
                self.previousCPUSampleUsec = nil
                self.previousCPUSampleTime = nil
            }
            return false
        }

        let sample: ContainerStats
        do {
            sample = try await container.stats()
        } catch {
            await MainActor.run { self.metrics.isAvailable = false }
            throw error
        }

        let now = ContinuousClock.now
        await MainActor.run {
            self.metrics.memoryUsageBytes = sample.memoryUsageBytes
            self.metrics.memoryLimitBytes = sample.memoryLimitBytes
            self.metrics.networkRxBytes = sample.networkRxBytes
            self.metrics.networkTxBytes = sample.networkTxBytes
            self.metrics.blockReadBytes = sample.blockReadBytes
            self.metrics.blockWriteBytes = sample.blockWriteBytes
            self.metrics.numProcesses = sample.numProcesses
            self.metrics.cpuUsageUsec = sample.cpuUsageUsec

            if let prevUsec = self.previousCPUSampleUsec,
               let prevTime = self.previousCPUSampleTime,
               let cpuUsec = sample.cpuUsageUsec,
               cpuUsec >= prevUsec {
                let deltaUsec = Double(cpuUsec - prevUsec)
                let elapsed = now - prevTime
                let elapsedSec = Double(elapsed.components.seconds)
                    + Double(elapsed.components.attoseconds) / 1e18
                if elapsedSec > 0 {
                    self.metrics.cpuPercent = (deltaUsec / 1_000_000) / elapsedSec * 100
                } else {
                    self.metrics.cpuPercent = nil
                }
            } else {
                self.metrics.cpuPercent = nil
            }

            self.previousCPUSampleUsec = sample.cpuUsageUsec
            self.previousCPUSampleTime = now
            self.metrics.isAvailable = true
        }
        return true
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
