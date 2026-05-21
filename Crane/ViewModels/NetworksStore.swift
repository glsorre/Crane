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
class Network: Identifiable, Hashable {
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
    private let networkClient = NetworkClient()
    private let onError: @MainActor (CraneError) -> Void
    private let containersForNetworkProvider: () -> [String: [Container]]
    private let tracker: ConnectionHealthTracker?

    var networks: Set<Network> = []
    var networksTask: Task<Void, Never>?
    var resetPolling: (() -> Void)?

    var searchText: String = ""

    var sortedFilteredNetworks: [Network] {
        networks
            .sorted { $0.id < $1.id }
            .filter { self.searchText.isEmpty || ($0.id.contains(self.searchText)) }
    }

    init(
        onError: @escaping @MainActor (CraneError) -> Void = { _ in },
        containersForNetwork: @escaping () -> [String: [Container]] = { [:] },
        tracker: ConnectionHealthTracker? = nil
    ) {
        self.onError = onError
        self.containersForNetworkProvider = containersForNetwork
        self.tracker = tracker
    }

    deinit {
        self.stop()
    }

    func stop() {
        self.networksTask?.cancel()
    }

    func start() {
        guard AppSettings.autoRefresh else { return }
        let tracker = self.tracker
        let (task, reset) = startAdaptivePolling(
            baseInterval: { AppSettings.refreshInterval },
            maxInterval: { AppSettings.maxPollingInterval },
            isVisible: { PollingVisibility.isVisible(for: .networks) },
            onError: { error in
                Task { @MainActor in
                    tracker?.recordFailure(resource: .networks, error: error)
                }
            },
            work: {
                try await self.collectWithChangeDetection()
            }
        )
        self.networksTask = task
        self.resetPolling = reset
    }

    @discardableResult
    func collect() async throws -> Bool {
        try await collectWithChangeDetection()
    }

    private func collectWithChangeDetection() async throws -> Bool {
        let previousIDs = Set(networks.map { $0.id })

        let currentNetworks = try await networkClient.list()
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

        let newIDs = Set(networks.map { $0.id })
        let tracker = self.tracker
        Task { @MainActor in
            tracker?.recordSuccess()
        }
        return previousIDs != newIDs
    }

    func reset() async throws {
        networks.removeAll()
        try await self.collect()
    }

    var hasEmptyNetworks: Bool {
        let containersForNetwork = containersForNetworkProvider()
        return networks.contains { network in
            !network.network.isBuiltin && (containersForNetwork[network.id] ?? []).isEmpty
        }
    }

    func pruneNetworks() async {
        let containersForNetwork = containersForNetworkProvider()
        let emptyNetworks = networks.filter { network in
            !network.network.isBuiltin && (containersForNetwork[network.id] ?? []).isEmpty
        }

        for network in emptyNetworks {
            network.transiting = true
            do {
                try await networkClient.delete(id: network.id)
                networks.remove(network)
            } catch {
                network.transiting = false
                Log.networks.error("network delete failed for \(network.id): \(error.localizedDescription, privacy: .public)")
                onError(.networkRemoveFailed(underlying: error))
            }
        }
        CraneMutationBus.postNetworkMutated()
    }

    func removeNetwork(id: String) async {
        guard let network = networks.first(where: { $0.id == id }) else { return }
        network.transiting = true
        do {
            try await networkClient.delete(id: network.id)
            networks.remove(network)
        } catch {
            network.transiting = false
            onError(.networkRemoveFailed(underlying: error))
        }
        CraneMutationBus.postNetworkMutated()
    }

    func createNetwork(id: String) async throws {
        let network = try await networkClient.create(
            configuration: try .init(
                id: id,
                mode: NetworkMode.nat,
                pluginInfo: NetworkPluginInfo(plugin: "container-network-vmnet")
            )
        )
        let networkModel = Network(network: network)
        networks.insert(networkModel)
        CraneMutationBus.postNetworkMutated()
    }
}
