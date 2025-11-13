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
    let id: Int
    var logs: [ContainerLogLine] = []
    var offset: Int64 = 0
    var reader: ScrollViewProxy? = nil
    var userScrolled: Bool = false
    var followLogs: Bool = true
    var nextLogId: Int = 0
    var forceScroll: Bool = false
    
    init(id: Int) {
        self.id = id
    }
}

@Observable
class ContainerMetadata: Identifiable {
    var id: String
    var transiting: Bool = false
    var logHandles: [ContainerLogsMetadata] = []
    var removing: Bool = false
    var loadingLogs: Bool = true
    var currentPollingTask: Task<Void, Never>? = nil
    
    init (id: String) {
        self.id = id
    }
    
    convenience init (_ container: ClientContainer) {
        self.init(id: container.id)
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
    var networks: Set<String>?
    var containersForNetwork: [String: [ClientContainer]] = [:]
    
    var containerToCreate: ContainerCreation = .init()
    var currentContainerId: String?
    var currentContainer: ClientContainer? {
        get {
            if let id = currentContainerId, let container = containers?[id] {
                return container
            } else {
                return nil
            }
        }
    }
    var showError: Bool = false
    var error: Error?
    var currentLogHandle: Int = 0
    
    func initState() async {
        await listContainers()
    }
    
    func listContainers() async {
        do {
            let newContainers = try await ClientContainer.list()
            
            let containersToRemove: [String] = containers!.keys.filter { key in !newContainers.contains(where: { $0.id == key }) }
            
            if containersToRemove.contains(currentContainerId ?? "") {
                currentContainerId = nil
                currentLogHandle = 0
            }
            
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
                    let metadata = ContainerMetadata(container)
                    containersMetadata?[container.id] = metadata
                } else {
                    containers![container.id] = container
                }
            }
            
            networks = Set(containers!.values.flatMap { $0.configuration.networks.map { $0.network } })
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
      guard let metadata = containersMetadata?[id] else {
          return 
      }
      
      defer { metadata.loadingLogs = false }
      
      do {
          let fileHandles = try await ClientContainer.get(id: id).logs()
          metadata.logHandles = (0..<fileHandles.count).map { ContainerLogsMetadata(id: $0) }
          for (index, handle) in fileHandles.enumerated() {
              if let streamReader = StreamReader(fileHandle: handle) {
                  defer {
                      streamReader.close()
                  }
                  while let line = streamReader.nextLine() {
                      let logLine = ContainerLogLine(id: metadata.logHandles[index].nextLogId, message: line)
                      metadata.logHandles[index].logs.append(logLine)
                      metadata.logHandles[index].nextLogId += 1
                  }
              }
              metadata.logHandles[index].offset = Int64(metadata.logHandles[index].logs.count)
          }
          await startPollingForSelectedHandle(for: id)
      } catch {
          self.error = error
          self.showError = true
          return
      }
  }
    
    func watchContainerLogs(for id: String, handle: Int) async {
        guard let metadata = containersMetadata?[id], handle < metadata.logHandles.count else { return }
        
        do {
            let container = try await ClientContainer.get(id: id)
            let fileHandle = try await container.logs()[handle]
            
            if let streamReader = StreamReader(fileHandle: fileHandle) {
                defer {
                    streamReader.close()
                }
                streamReader.skipLines(Int(metadata.logHandles[handle].offset))
                while let line = streamReader.nextLine() {
                    let logLine = ContainerLogLine(id: metadata.logHandles[handle].nextLogId, message: line)
                    metadata.logHandles[handle].logs.append(logLine)
                    metadata.logHandles[handle].nextLogId += 1
                }
            }
            
            metadata.logHandles[handle].offset = Int64(metadata.logHandles[handle].logs.count)
            
            if metadata.logHandles[handle].followLogs && !metadata.logHandles[handle].userScrolled {
                metadata.logHandles[handle].forceScroll = true
            }
        } catch {
            self.error = error
            self.showError = true
            return
        }
    }
    
    private func startPollingForSelectedHandle(for containerId: String) async {
        guard let metadata = containersMetadata?[containerId],
              currentLogHandle < metadata.logHandles.count else { return }
        let logMetadata = metadata.logHandles[currentLogHandle]
        
        metadata.currentPollingTask?.cancel()
        
        metadata.currentPollingTask = Task {
            while !Task.isCancelled {
                if logMetadata.followLogs && !logMetadata.userScrolled {
                    await self.watchContainerLogs(for: containerId, handle: currentLogHandle)
                }
                try? await Task.sleep(for: .seconds(UserDefaults().integer(forKey: "logsInterval")))
            }
        }
    }
    
    func selectLogHandle(for containerId: String, handle: Int) {
        currentLogHandle = handle
        Task { await startPollingForSelectedHandle(for: containerId) }
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
        currentContainerId = nil
        currentLogHandle = 0
        containersMetadata?[id]?.removing = false
        containers?.removeValue(forKey: id)
        await listContainers()
    }
}

