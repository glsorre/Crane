//
//  CraneNetworksListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerClient
import ContainerNetworkService
import SwiftUI

enum NetworkListItem {
    case network(AttachmentConfiguration)
    case container(ClientContainer, networkKey: String)
    
    static var sortOrderComparator: KeyPathComparator<NetworkListItem> {
        .init(\.id, order: .forward)
    }
    
    var id: String {
        switch self {
        case .network(let config):
            return config.id
        case .container(let container, let networkKey):
            return "\(container.id)-\(networkKey)"
        }
    }
}

extension NetworkListItem: Identifiable {}

extension NetworkListItem: Hashable {
    static func == (lhs: NetworkListItem, rhs: NetworkListItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct CraneNetworksListView: View {
    @Bindable var viewModel: CraneViewModel
    @State private var selection: NetworkListItem.ID? = nil
    @State private var expandedNetworks: [String: Bool] = [:]
    
    private var rawNetworks: [String: [ClientContainer]] {
        return viewModel.containersForNetwork
    }
    
    private var allSortedNetworks: [(String, [ClientContainer])] {
        return rawNetworks.sorted { $0.key < $1.key }
    }
    
    private var sortedFilteredContainers: [(String, [ClientContainer])] {
        let searchText = viewModel.searchText
        if searchText.isEmpty {
            return allSortedNetworks
        } else {
            return allSortedNetworks.filter { key, _ in
                key.contains(searchText)
            }
        }
    }
    
    private func networkForKey(_ key: String) -> NetworkListItem? {
        guard let config = viewModel.networks?[key] else {
            return nil
        }
        return .network(config)
    }
    
    private func childrenForNetwork(_ key: String) -> [NetworkListItem] {
        let containers = viewModel.containersForNetwork[key] ?? []
        return containers.map { .container($0, networkKey: key) }
    }
    
    private func itemForID(_ id: NetworkListItem.ID?) -> NetworkListItem? {
        guard let id = id else { return nil }
        for (key, containers) in rawNetworks {
            if let config = viewModel.networks?[key], config.id == id {
                return .network(config)
            }
            for container in containers {
                if "\(container.id)-\(key)" == id {
                    return .container(container, networkKey: key)
                }
            }
        }
        return nil
    }
    
    var body: some View {
        Table(of: NetworkListItem.self, selection: $selection) {
            TableColumn("Name") { item in
                switch item {
                case .network(let network):
                    Label(network.network, systemImage: "network.fill")
                        .padding(5)
                case .container(let container, _):
                    Label(container.id, systemImage: container.status.getIcon())
                        .padding(5)
                        .foregroundColor(.secondary)
                }
            }
            TableColumn("IP") { item in
                switch item {
                case .network:
                    EmptyView()
                case .container(let container, let networkKey):
                    let attachment = container.networks.first { $0.network == networkKey }
                    Text(attachment?.address ?? "No IP").foregroundColor(.secondary)
                }
            }
            TableColumn("") { item in
                switch item {
                case .network:
                    EmptyView()
                case .container(let container, _):
                    ContainerListActionsView(viewModel: viewModel, id: container.id)
                }
            }
            .width(100)
        } rows: {
            ForEach(sortedFilteredContainers, id: \.0) { networkKey, _ in
                if let networkItem = networkForKey(networkKey) {
                    let childrenItems = childrenForNetwork(networkKey)
                    
                    let isExpanded = expandedNetworks[networkKey, default: true]
                    DisclosureTableRow(networkItem, isExpanded: Binding(
                        get: { isExpanded },
                        set: { expandedNetworks[networkKey] = $0 }
                    )) {
                        ForEach(childrenItems, id: \.id) { childItem in
                            TableRow(childItem)
                        }
                    }
                }
            }
        }
        .tableStyle(.bordered)
        .onChange(of: selection) { _, newValue in
            if let item = itemForID(newValue) {
                switch item {
                case .network:
                    selection = nil
                case .container(let container, _):
                    selection = nil
                    viewModel.path.append(CraneRoute.detail(id: container.id))
                }
            }
        }
    }
}

