//
//  ViewModel.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 10/11/25.
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
class ContainerLogsMetadata: Identifiable {
    var logs: [ContainerLogLine] = []
    var offset: Int64 = 0
    var userScrolled: Bool = false
    var followLogs: Bool = true
    var nextLogId: Int = 0
    var forceScroll: Bool = false
    
    var logPollingTask: Task<Void, Never>? = nil
}

@Observable
class ContainerMetadata {
    var transiting: Bool = false
    var logHandles: [Int: ContainerLogsMetadata] = [:]
    var removing: Bool = false
    var loadingLogs: Bool = true
    var currentPollingTask: Task<Void, Never>? = nil
    
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

@Observable
class ContainerCreation {
    var creating: Bool = false
    var name: String = ""
    var image: String = ""
    var cpus: Int64 = 1
    var memory: String = "1Gi"
    var publishPorts: [String] = []
    var networks: [String] = []
    var remove: Bool = false
}

struct ErrorWrapper: Identifiable {
    var error: any Error
    var id: UUID = UUID()
}

@Observable
class CraneViewModel {
    var containers: [String: ClientContainer]? = [:]
    var containersMetadata: [String: ContainerMetadata]? = [:]
    var networks: [String: AttachmentConfiguration]?
    var containersForNetwork: [String: [ClientContainer]] = [:]
    
    var showError: Bool = false
    var error: Error?
    
    var path: NavigationPath = NavigationPath()
    var currentHandle: Int = 0
    
    var searchText: String = ""
    
    func initState() async {
        await listContainers()
    }
    
    func listContainers() async {
        do {
            let newContainers = try await ClientContainer.list()
            
            let containersToRemove: [String] = containers!.keys.filter { key in !newContainers.contains(where: { $0.id == key }) }
            
            for id in containersToRemove {
                containers?.removeValue(forKey: id)
                containersMetadata?.removeValue(forKey: id)
            }
            
            if containers == nil {
                containers = [:]
            }
            if containersMetadata == nil {
                containersMetadata = [:]
            }
            
            for container in newContainers {
                if !containers!.keys.contains(container.id) {
                    containers?[container.id] = container
                    let metadata = ContainerMetadata()
                    containersMetadata?[container.id] = metadata
                } else {
                    containers![container.id] = container
                }
            }
            
            networks = Dictionary(grouping: containers!.values.flatMap { $0.configuration.networks }, by: \.network).mapValues { $0.first! }
            containersForNetwork = Dictionary(grouping: containers!.values.flatMap { container in
                container.configuration.networks.map { ($0.network, container) }
            }, by: \.0).mapValues { $0.map(\.1) }
        } catch {
            self.error = error
            self.showError = true
            return
        }
    }
    
    func stopContainer(id: String) async {
        containersMetadata?[id]?.transiting = true
        do {
            try await ClientContainer.get(id: id).stop(opts: .default)
        } catch {
            self.error = error
            self.showError = true
            return
        }
        containersMetadata?[id]?.transiting = false
        
        await listContainers()
    }
    
    func startContainer(id: String) async {
        containersMetadata?[id]?.transiting = true
        do {
            let io = try ProcessIO.create(
                tty: false,
                interactive: false,
                detach: true
            )
            defer {
                try? io.close()
            }
            let process = try await ClientContainer.get(id: id).bootstrap(stdio: io.stdio)
            try await process.start()
        } catch {
            self.error = error
            self.showError = true
        }
        await initContainerLogs(for: id)
        containersMetadata?[id]?.transiting = false
        await listContainers()
    }
    
    func initContainerLogs(for id: String) async {
        guard let metadata = containersMetadata?[id] else { return }
        
        do {
            let fileHandles = try await ClientContainer.get(id: id).logs()
            metadata.logHandles = Dictionary(uniqueKeysWithValues: (0..<fileHandles.count).map { ($0, ContainerLogsMetadata()) })
            for (index, handle) in fileHandles.enumerated() {
                if let streamReader = StreamReader(fileHandle: handle) {
                    defer {
                        streamReader.close()
                    }
                    while let line = streamReader.nextLine() {
                        let logLine = ContainerLogLine(id: metadata.logHandles[index]!.nextLogId, message: line)
                        metadata.logHandles[index]!.logs.append(logLine)
                        metadata.logHandles[index]!.nextLogId += 1
                    }
                }
                metadata.logHandles[index]!.offset = Int64(metadata.logHandles[index]!.logs.count)
            }
        } catch {
            self.error = error
            self.showError = true
            return
        }
    }
    
    func watchContainerLogs(for id: String, handle: Int) async {
        guard let metadata = containersMetadata?[id],
              handle < metadata.logHandles.count,
              let logMetadata = metadata.logHandles[handle] else { return }
        
        do {
            let container = try await ClientContainer.get(id: id)
            let fileHandle = try await container.logs()[handle]
            
            if let streamReader = StreamReader(fileHandle: fileHandle) {
                defer {
                    streamReader.close()
                }
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
        } catch {
            self.error = error
            self.showError = true
            return
        }
    }
    
    func removeContainer(id: String) async {
        containersMetadata?[id]?.currentPollingTask?.cancel()
        
        containersMetadata?[id]?.removing = true
        do {
            try await ClientContainer.get(id: id).delete()
        } catch {
            self.error = error
            self.showError = true
            return
        }

        currentHandle = 0
        containersMetadata?[id]?.removing = false
        containers?.removeValue(forKey: id)
        await listContainers()
    }
}
