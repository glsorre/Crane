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
class DetailsViewModel {
    var container: Container
    var currentHandle: Int = 0

    var logHandles: [Int: ContainerLogStream] = [:]

    var streamingTask: Task<Void, Never>? = nil

    init(container: Container) {
        self.container = container
        self.start(handleIndex: self.currentHandle)
    }

    deinit {
        self.stop()
    }

    func bootstrap() async {
        do {
            let handlesCount = try await container.container.logs().count

            for handleIndex in 0..<handlesCount {
                self.logHandles[handleIndex] = ContainerLogStream()
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

                let fileHandle = try await container.container.logs()[handleIndex]

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

    func removeContainer() async {
        do {
            try await container.remove()
        } catch {
            AppViewModel.shared.showError(.containerRemoveFailed(error.localizedDescription))
        }

        AppViewModel.shared.navigateTo(to: CraneRoute.list, removeStack: true)
    }

    func getHandleName(handleIndex: Int) -> String {
        if (handleIndex < logHandles.count - 1) {
            if (handleIndex == 0) {
                return "Process"
            }
            return "Process \(handleIndex + 1)"
        } else {
            return "System"
        }
    }
}
