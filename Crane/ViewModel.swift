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

@Observable
class ContainerMetadata: Identifiable {
    var id: String
    var transiting: Bool = false
    var loadingLogs: Bool = true
    var followLogs: Bool = true
    var logs: [String] = []
    var logsOffsets: [UInt64] = []
    var loadingMoreLogs: Bool = false
    var removing: Bool = false
    
    init (id: String) {
        self.id = id
    }
    
    convenience init (_ container: ClientContainer) {
        self.init(id: container.id)
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
    var containers: [String: ClientContainer]? = [:]  // Changed to dict for accumulation by ID; prevents dropping stopped containers
    var containersMetadata: [ContainerMetadata]? = []
    var networks: Set<Attachment>?
    
    var containerToCreate: ContainerCreation = .init()
    var currentContainerId: String?
    var error: Error?
    var logPollingTask: Task<Void, Never>?
    var reader: ScrollViewProxy?
    var userScrolled = false
    var showCreateSheet = false
    
    func initState() async {
        await listContainers()
        containersMetadata = containers?.values.map(ContainerMetadata.init)  // Updated to map over dict values
    }
    
    func listContainers() async {
        do {
            let newContainers = try await ClientContainer.list()
            
            // Accumulate all seen containers (by ID) to persist stopped ones; update/refresh running ones
            if containers == nil {
                containers = [:]
            }
            for container in newContainers {
                containers?[container.id] = container  // Adds or updates
            }
            
            // Networks: recalculate from current dict (excludes old stopped ones if they had stale networks, but keeps them listed)
            networks = Set(containers!.values.flatMap { $0.networks })  // Force-unwrap for simplicity; add nil check if needed
            
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
        await getContainerLogs(for: id)
        containersMetadata?.fromIndex(id)?.transiting = false
        await listContainers()
    }
    
    private func extractLogLines(from input: String) -> [String] {
        let lines = input.components(separatedBy: .newlines).flatMap { line in
            line.components(separatedBy: CharacterSet(charactersIn: "\r"))
        }
        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
    
    func getContainerLogs(for id: String, prependMore: Bool = false) async {
        guard let metadata = containersMetadata?.fromIndex(id) else { return }
        
        do {
            let container = try await ClientContainer.get(id: id)
            let handles = try await container.logs()
            
            if prependMore {
                guard !handles.isEmpty,
                      metadata.logsOffsets.contains(where: { $0 > 0 }),
                      !Task.isCancelled else { return }
                
                metadata.loadingMoreLogs = true
                
                // Optimized constants for faster loads
                let assumedBytesPerLine: UInt64 = 60  // Reduced from 120 for quicker estimates and reads
                let linesPerLoad = 50  // Reduced from 200 to make loads snappier and more incremental
                let totalBufferSize: UInt64 = UInt64(linesPerLoad) * assumedBytesPerLine * UInt64(max(1, handles.count))
                let bufferSizePerHandle = totalBufferSize / UInt64(max(1, handles.count))
                
                var allNewLines: [String] = []
                
                // Process handles concurrently using TaskGroup for parallel I/O where possible
                try await withThrowingTaskGroup(of: (Int, [String], UInt64).self) { group in
                    for (i, handle) in handles.enumerated() {
                        guard !Task.isCancelled else { return }
                        
                        group.addTask {
                            let lastOffset = await metadata.logsOffsets[i]
                            guard lastOffset > 0 else { return (i, [], 0) }
                            
                            let seekBack = min(lastOffset, bufferSizePerHandle)
                            let startOffset = lastOffset - seekBack
                            handle.seek(toFileOffset: startOffset)
                            
                            let data: Data
                            if seekBack > 0 {
                                data = handle.readData(ofLength: Int(seekBack))
                            } else {
                                data = Data()
                            }
                            
                            var extractedLines: [String] = []
                            if let str = String(data: data, encoding: .utf8) {
                                extractedLines = await self.extractLogLines(from: str).suffix(linesPerLoad)
                                // Limit extraction to avoid over-processing large chunks
                            }
                            
                            let updatedOffset = startOffset
                            return (i, extractedLines, updatedOffset)
                        }
                    }
                    
                    for try await (i, lines, newOffset) in group {
                        guard !Task.isCancelled else { continue }
                        
                        allNewLines.append(contentsOf: lines)
                        metadata.logsOffsets[i] = newOffset
                    }
                }
                
                if !allNewLines.isEmpty {
                    // Enforce a max log size to prevent unbounded array growth and insertion slowdowns
                    let maxLines = 1000  // Adjust as needed; keeps performance snappy
                    if metadata.logs.count > maxLines {
                        metadata.logs = Array(metadata.logs.dropFirst(metadata.logs.count - maxLines))
                    }
                    
                    // Prepend efficiently for faster UI updates (newest at top now shown first)
                    metadata.logs.insert(contentsOf: allNewLines.reversed(), at: 0)  // Reverse to maintain order
                }
                
                print("DEBUG: Prepended \(allNewLines.count) optimized older log lines for \(id) (total logs: \(metadata.logs.count))")
                metadata.loadingMoreLogs = false
                
                return
            }
            
            // Existing logic for initial/incremental loads (unchanged except for minor buffer tweaks if needed)
            var allNewLines: [String] = []
            
            if metadata.logsOffsets.isEmpty {
                let linesPerLoad = 100  // Kept similar, but you could reduce further for initial loads if testing shows slowness
                for (i, handle) in handles.enumerated() {
                    let fileSize = handle.seekToEndOfFile()
                    handle.seek(toFileOffset: 0)
                    
                    let assumedBytesPerLine: UInt64 = 120
                    let bufferSize: UInt64 = UInt64(linesPerLoad) * assumedBytesPerLine
                    let startOffset = fileSize > bufferSize ? fileSize - bufferSize : 0
                    handle.seek(toFileOffset: startOffset)
                    let data = handle.readDataToEndOfFile()
                    
                    let currentOffset = handle.offsetInFile
                    
                    if let str = String(data: data, encoding: .utf8) {
                        let lines = self.extractLogLines(from: str)
                        allNewLines.append(contentsOf: lines)
                    } else {
                        print("DEBUG: Handle \(i) for \(id) returned non-UTF-8 data; no lines extracted")
                    }
                    metadata.logsOffsets.append(currentOffset)
                }
                allNewLines = Array(allNewLines.suffix(linesPerLoad))
                print("DEBUG: Initial optimized load of \(allNewLines.count) log lines for \(id)")
            } else {
                for (i, handle) in handles.enumerated() {
                    let lastOffset = metadata.logsOffsets[i]
                    handle.seek(toFileOffset: lastOffset)
                    let data = handle.readDataToEndOfFile()
                    let currentOffset = handle.offsetInFile
                    
                    if let str = String(data: data, encoding: .utf8) {
                        let lines = self.extractLogLines(from: str)
                        allNewLines.append(contentsOf: lines)
                    }
                    metadata.logsOffsets[i] = currentOffset
                }
                print("DEBUG: Incremental optimized load of \(allNewLines.count) new log lines for \(id)")
            }
            
            if !allNewLines.isEmpty {
                metadata.logs.append(contentsOf: allNewLines)
                // Optional: Enforce max lines here too to keep arrays small across all load types
                if metadata.logs.count > 2000 {  // Separate limit for append loads
                    metadata.logs = Array(metadata.logs.suffix(2000))
                }
            }
            
            print("DEBUG: Total logs for \(id): \(metadata.logs.count)")
            
        } catch {
            print("DEBUG ERROR: Failed to load logs for \(id): \(error)")
            self.error = error
        }
    }
    
    func hideAndGetContainerLogs(for id: String) async {
        if let metadata = containersMetadata?.fromIndex(id) {
            metadata.loadingLogs = true
            await getContainerLogs(for: id)
            metadata.loadingLogs = false
        }
    }
    
    func removeContainer(id: String) async {
        containersMetadata?.fromIndex(id)?.removing = true
        do {
            try await ClientContainer.get(id: id).delete()
        } catch {
            self.error = error
        }
        containersMetadata?.fromIndex(id)?.removing = false
        containers?[id] = nil  // Actually remove from dict on user delete
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
                registry: registryFlags ?? Flags.Registry(),
                progressUpdate: { message in
                    print("Mock progress: \(message)")
                }
            )

            let options = ContainerCreateOptions(autoRemove: remove)
            let container = try await ClientContainer.create(configuration: ck.0, options: options, kernel: ck.1)
            await listContainers()
        } catch {
            self.error = error
        }
    }
}
