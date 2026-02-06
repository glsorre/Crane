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
class Container : Identifiable, Hashable {
    static func == (lhs: Container, rhs: Container) -> Bool {
        lhs.id == rhs.id
    }
    
    static func == (lhs: Container, rhs: ClientContainer) -> Bool {
        lhs.id == rhs.id
    }
    
    static func == (lhs: ClientContainer, rhs: Container) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var id: String
    var container: ClientContainer
    var transiting: Bool
    
    init(container: ClientContainer) {
        self.id = container.id
        self.container = container
        self.transiting = false
    }
    
    func update(container: ClientContainer) {
        self.container = container
    }
    
    func start() async throws {
        self.transiting = true
        
        try await withTimeout() {
            let io = try ProcessIO.create(tty: true, interactive: false, detach: true)
            defer {
                _ = try? io.close()
            }
            let process = try await self.container.bootstrap(stdio: io.stdio)
            try await process.start()
        }
        
        try await Task.sleep(for: .seconds(5))
        self.transiting = false
    }
    
    func stop() async throws {
        self.transiting = true
        
        try await withTimeout() {
            try await self.container.stop()
        }
        
        try await Task.sleep(for: .seconds(5))
        self.transiting = false
    }
    
    func remove() async throws {
        self.transiting = true
        
        try await withTimeout() {
            try await self.container.delete()
        }
    }
}

@Observable
class ContainersStore {
    static let shared = ContainersStore()
    
    var containers: Set<Container> = []
    var containersTask: Task<Void, Never>? = nil

    var searchText: String = ""
    
    var sortedFilteredContainers: [Container] {
        containers
            .sorted { $0.id < $1.id }
            .filter { self.searchText.isEmpty || ($0.id.contains(self.searchText)) }
    }

    var images: [ImageDescription] {
        Set(containers).compactMap { $0.container.configuration.image }
    }

    var containersForImage: [String: [Container]] {
        Dictionary(grouping: containers) { $0.container.configuration.image.reference }
    }

    var networks: [AttachmentConfiguration] {
        containers.flatMap { $0.container.configuration.networks }
    }

    var containersForNetwork: [String: [Container]] {
        Dictionary(grouping: containers.flatMap { container in
            container.container.configuration.networks.map { ($0, container) }
        }, by: { $0.0.network }).mapValues { $0.map(\.1) }
    }
    
    private init() {
        self.start()
    }
    
    deinit {
        self.stop()
    }
    
    func stop() {
        self.containersTask?.cancel()
    }

    func start() {
        self.containersTask = startPolling(interval: { AppSettings.refreshInterval }) {
            try await self.collect()
        }
    }
    
    func collect() async throws {
        let currentContainers = try await ClientContainer.list()
        var currentContainersSet: Set<Container> = Set()
        
        for clientContainer in currentContainers {
            let newContainer = Container(container: clientContainer)
            currentContainersSet.insert(newContainer)
            if let container = containers.first(where: { $0.id == newContainer.id }) {
                container.update(container: clientContainer)
            }
            containers.insert(newContainer)
        }
        
        let containersToRemove = containers.subtracting(currentContainersSet)
        containersToRemove.forEach { containerToRemove in
            containers.remove(containerToRemove)
        }
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
            AppViewModel.shared.showError(.containerStartFailed(error.localizedDescription))
        }
    }

    func stopContainer(id: String) async {
        guard let container = containers.first(where: { $0.id == id }) else { return }
        do {
            try await container.stop()
        } catch {
            AppViewModel.shared.showError(.containerStopFailed(error.localizedDescription))
        }
    }

    func removeContainer(id: String) async {
        guard let container = containers.first(where: { $0.id == id }) else { return }
        do {
            try await container.remove()
        } catch {
            AppViewModel.shared.showError(.containerRemoveFailed(error.localizedDescription))
        }
    }
}

