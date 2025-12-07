//
//  DetailsViewModel.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 06/12/25.
//

import ContainerClient
import ContainerNetworkService
import ContainerizationOCI
import Foundation
import Combine
import Observation
import SwiftUI

struct ContainerLogLine: Identifiable {
    let id: Int
    let message: String
}

@Observable
class ContainerLogStream: Identifiable {
    var logs: [ContainerLogLine] = []
    var offset: Int64 = 0
    var userScrolled: Bool = false
    var followLogs: Bool = true
    var nextLogId: Int = 0
    var forceScroll: Bool = false
}

@Observable
class DetailsViewModel: ObservableObject {
    var container: Container
    var currentHandle: Int = 0
    
    var logHandles: [Int: ContainerLogStream] = [:]
    
    var logsRefresher: Task<Void, Never>? = nil
    
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
            print("Failed to get log handles count: \(error)")
        }
    }
    
    func start(handleIndex: Int) {
        self.logsRefresher?.cancel()
        
        self.logsRefresher = Task {
            do {
                while !Task.isCancelled {
                    if self.logHandles[handleIndex] == nil {
                        self.logHandles[handleIndex] = ContainerLogStream()
                    }
                    
                    try await self.readLogHandle(handleIndex: handleIndex)
                    try await Task.sleep(for: .seconds(UserDefaults().integer(forKey: "logsInterval")))
                }
            } catch {
                print("Log refresh failed: \(error)")
            }
        }
    }
    
    func stop() {
        self.logsRefresher?.cancel()
        self.logsRefresher = nil
    }
    
    func startContainer() async throws {
        do {
            try await container.start()
        } catch {
            print("Failed to start container: \(error)")
        }
    }
    
    func stopContainer() async throws {
        do {
            try await container.stop()
        } catch {
            print("Failed to stop container: \(error)")
        }
    }
    
    func removeContainer() async throws {
        do {
            try await container.remove()
        } catch {
            print("Failed to remove container: \(error)")
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
    
    func readLogHandle(handleIndex: Int) async throws {
        guard handleIndex < self.logHandles.count,
              let logMetadata = self.logHandles[handleIndex] else { return }
        
        let fileHandle = try await container.container.logs()[handleIndex]
        if let streamReader = StreamReader(fileHandle: fileHandle) {
            streamReader.skipLines(Int(logMetadata.offset))
            while let line = streamReader.nextLine() {
                let logLine = ContainerLogLine(id: logMetadata.nextLogId, message: line)
                logMetadata.logs.append(logLine)
                logMetadata.nextLogId += 1
            }
        }
        
        logMetadata.offset = Int64(logMetadata.logs.count)
        
        if logMetadata.followLogs && !logMetadata.userScrolled {
            logMetadata.forceScroll = true
        }
    }
}

