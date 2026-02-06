//
//  NetworksStore.swift
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
        networks
            .sorted { $0.id < $1.id }
            .filter { self.searchText.isEmpty || ($0.id.contains(self.searchText)) }
    }
    
    private init() {
        self.start()
    }
    
    deinit {
        self.stop()
    }
    
    func stop() {
        self.networksTask?.cancel()
    }

    func start() {
        self.networksTask = startPolling(interval: { AppSettings.refreshInterval }) {
            try await self.collect()
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
        networksToRemove.forEach { networkToRemove in
            networks.remove(networkToRemove)
        }
    }
    
    func reset() async throws {
        networks.removeAll()
        try await self.collect()
    }
    
    func createNetwork(id: String) async throws {
        let network = try await ClientNetwork.create(configuration: try .init(id: id, mode: NetworkMode.nat))
        let networkModel = Network(network: network)
        networks.insert(networkModel)
    }
}
