//
//  ViewModel.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 10/11/25.
//

import ContainerClient
import ContainerNetworkService
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
    var logs: [ContainerLogLine] = []  // Changed: Now [LogLine] for stable IDs
    var offset: Int64 = 0
    var reader: ScrollViewProxy? = nil
    var userScrolled: Bool = false
    var followLogs: Bool = true
    var nextLogId: Int = 0  // Added: For assigning stable, incrementing IDs to log lines
    // Removed individual logPollingTask; now managed per container
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
    var currentPollingTask: Task<Void, Never>? = nil  // Added: single task for selected handle
    
    init (id: String) {
        self.id = id
    }
    
    convenience init (_ container: ClientContainer) {
        self.init(id: container.id)
    }
    
    func getHandleName(handleIndex: Int) -> String {
        if (handleIndex < logHandles.count - 1) {
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

@Observable
class ViewModel {
    var containers: [String: ClientContainer]? = [:]
    var containersMetadata: [ContainerMetadata]? = []
    var networks: Set<Attachment>?
    
    var containerToCreate: ContainerCreation = .init()
    var currentContainerId: String?
    var currentContainer: ClientContainer {
        get {
            if let id = currentContainerId, let container = containers?[id] {
                return container
            } else {
                fatalError("No container selected")
            }
        }
    }
    var error: Error?
    var showCreateSheet = false
    var selectedLogHandleIndex: Int = 0
    
    func initState() async {
        await listContainers()
        containersMetadata = containers?.values.map(ContainerMetadata.init)
    }
    
    func listContainers() async {
        do {
            let newContainers = try await ClientContainer.list()
            
            if containers == nil {
                containers = [:]
            }
            for container in newContainers {
                containers?[container.id] = container
            }
            
            networks = Set(containers!.values.flatMap { $0.networks })
            
        } catch {
            self.error = error
        }
    }
    
    func stopContainer(id: String) async {
        containersMetadata?.fromIndex(id)?.transiting = true
        do {
            try await ClientContainer.get(id: id).stop()
        } catch {
            self.error = error
        }
        containersMetadata?.fromIndex(id)?.transiting = false
        await listContainers()
    }
    
    func startContainer(id: String) async {
        containersMetadata?.fromIndex(id)?.transiting = true
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
        }
        await initContainerLogs(for: id)
        containersMetadata?.fromIndex(id)?.transiting = false
        await listContainers()
    }
    
    func initContainerLogs(for id: String) async {
      guard let metadata = containersMetadata?.fromIndex(id) else { 
          print("DEBUG: No metadata for container \(id)")
          return 
      }
      
      // Ensure we always reset the loading state, even on failure or early exit
      defer { metadata.loadingLogs = false }
      
      do {
          let fileHandles = try await ClientContainer.get(id: id).logs()
          print("DEBUG: Loaded \(fileHandles.count) log handles for \(id)")
                    
          // Initialize logHandles based on the number of file handles, with stable IDs starting at 0
          metadata.logHandles = (0..<fileHandles.count).map { ContainerLogsMetadata(id: $0) }
          
          // Load initial logs for each handle, assigning sequential IDs
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
              print("DEBUG: Handle \(index) has \(metadata.logHandles[index].logs.count) logs")
          }
          
          // Start polling only for the selected handle after initial load
          await startPollingForSelectedHandle(for: id)
      } catch {
          print("DEBUG: Error loading logs for \(id): \(error)")
          self.error = error
      }
  }
    
    func watchContainerLogs(for id: String, handle: Int) async {
        guard let metadata = containersMetadata?.fromIndex(id), handle < metadata.logHandles.count else { return }
        
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
            
            // Added: Trigger scroll if following logs
            if metadata.logHandles[handle].followLogs && !metadata.logHandles[handle].userScrolled {
                metadata.logHandles[handle].forceScroll = true
            }
        } catch {
            self.error = error
        }
    }
    
    // Added: Start polling only for the selected handle, respecting followLogs and userScrolled
    private func startPollingForSelectedHandle(for containerId: String) async {
        guard let metadata = containersMetadata?.fromIndex(containerId),
              selectedLogHandleIndex < metadata.logHandles.count else { return }
        let logMetadata = metadata.logHandles[selectedLogHandleIndex]
        
        // Cancel any existing polling task before starting a new one
        metadata.currentPollingTask?.cancel()
        
        metadata.currentPollingTask = Task {
            while !Task.isCancelled {
                if logMetadata.followLogs && !logMetadata.userScrolled {
                    await self.watchContainerLogs(for: containerId, handle: selectedLogHandleIndex)
                }
                try? await Task.sleep(for: .seconds(1))  // Poll every 1 second; adjust as needed
            }
        }
    }
    
    // Added: Method to select a new log handle and restart polling for it
    func selectLogHandle(for containerId: String, handle: Int) {
        selectedLogHandleIndex = handle  // Update the global selected index
        Task { await startPollingForSelectedHandle(for: containerId) }  // Restart polling for the new handle
    }
    
    func removeContainer(id: String) async {
        // Cancel polling task before removal
        containersMetadata?.fromIndex(id)?.currentPollingTask?.cancel()
        
        containersMetadata?.fromIndex(id)?.removing = true
        do {
            try await ClientContainer.get(id: id).delete()
        } catch {
            self.error = error
        }
        containersMetadata?.fromIndex(id)?.removing = false
        containers?[id] = nil
        await listContainers()
    }
    
    func createContainer(name: String, image: String, processFlags: Flags.Process?, managementFlags: Flags.Management?, resourceFlags: Flags.Resource?, registryFlags: Flags.Registry?, remove: Bool) async {
        do {
            let id = Utility.createContainerID(name: name)
            try Utility.validEntityName(id)
            
            let ck = try await Utility.containerConfigFromFlags(
                id: id,
                image: image,
                arguments: [],
                process: processFlags ?? Flags.Process(),
                management: managementFlags ?? Flags.Management(),
                resource: resourceFlags ?? Flags.Resource(),
                registry: Flags.Registry(),
                progressUpdate: { message in
                    print("Mock progress: \(message)")
                }
            )

            let options = ContainerCreateOptions(autoRemove: remove)
            _ = try await ClientContainer.create(configuration: ck.0, options: options, kernel: ck.1)
            await listContainers()
        } catch {
            self.error = error
        }
    }
}
