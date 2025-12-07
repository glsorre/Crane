//
//  NetworksStore.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 08/12/25.
//

import ContainerClient
import ContainerNetworkService
import ContainerizationOCI
import Foundation
import Combine
import Observation
import SwiftUI

@Observable
class Network : Identifiable, Hashable {
    static func == (lhs: Network, rhs: Network) -> Bool {
        lhs.id == rhs.id
    }
    
    static func == (lhs: Network, rhs: NetworkState) -> Bool {
        lhs.id == rhs.id
    }
    
    static func == (lhs: NetworkState, rhs: Network) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var id: String
    var network: NetworkState
    var transiting: Bool
    
    init(network: NetworkState) {
        self.id = network.id
        self.network = network
        self.transiting = false
    }
    
    func update(network: NetworkState) {
        self.network = network
    }
}

@Observable
class NetworksStore {
    static let shared = NetworksStore()
    
    var networks: Set<Network> = []
    var networksTask: Task<Void, Never>? = nil

    var searchText: String = ""
    
    var sortedFilteredNetworks: [Network] {
        get {
            networks
                .sorted { $0.id < $1.id }
                .filter { self.searchText.isEmpty || ($0.id.contains(self.searchText)) }
        }
    }
    
    var containersForNetwork: [String: [Container]] {
        get {
            Dictionary(grouping: ContainersStore.shared.containers.flatMap { container in
                container.container.configuration.networks.map { ($0.network, container) }
            }, by: \.0).mapValues { $0.map(\.1) }
        }
    }
    
    private init() {
        self.start()
    }
    
    deinit {
        self.stop()
    }
    
    func stop() {
        self.networksTask?.cancel()
        self.networksTask = nil
    }
    
    func start() {
        self.networksTask = Task {
            while !Task.isCancelled {
                _ = try? await self.collect()
                try? await Task.sleep(for: .seconds(UserDefaults().integer(forKey: "refreshInterval")))
            }
        }
    }
    
    func collect() async throws {
        let currentNetworks = try await ClientNetwork.list()
        var currentNetworksSet: Set<Network> = Set()
        
        for networkState in currentNetworks {
            let newNetwork = Network(network: networkState)
            currentNetworksSet.insert(newNetwork)
            if let network = networks.first(where: { $0.id == newNetwork.id }) {
                network.update(network: networkState)
            }
            networks.insert(newNetwork)
        }
        
        let networksToRemove = networks.subtracting(currentNetworksSet)
        networksToRemove.forEach { imageToRemove in
            networks.remove(imageToRemove)
        }
    }
    
    func reset() async throws {
        networks.removeAll()
        try await self.collect()
    }
}
