//
//  CraneNetworksListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

enum NetworkListItem {
    case network(Network)
    case container(Container, networkKey: String)
    
    static var sortOrderComparator: KeyPathComparator<NetworkListItem> {
        .init(\.id, order: .forward)
    }
    
    var id: String {
        switch self {
        case .network(let network):
            return network.id
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
    @State private var appViewModel = AppViewModel.shared
    @State private var networksStore = NetworksStore.shared
    @State private var selection: NetworkListItem.ID? = nil
    @State private var expandedNetworks: [String: Bool] = [:]
    
    @State private var creatingPopupIsVisible: Bool = false
    @State private var networkToCreate: String = ""
    
    private func networkForKey(_ key: String) -> NetworkListItem? {
        guard let network = networksStore.networks.first(where: { $0.id == key }) else {
            return nil
        }
        return .network(network)
    }
    
    private func childrenForNetwork(_ key: String) -> [NetworkListItem] {
        let containers = ContainersStore.shared.containersForNetwork[key] ?? []
        return containers.map { .container($0, networkKey: key) }
    }
    
    private func itemForID(_ id: NetworkListItem.ID?) -> NetworkListItem? {
        guard let id = id else { return nil }
        for network in networksStore.networks {
            if network.id == id {
                return .network(network)
            }
        }
        for (key, containers) in ContainersStore.shared.containersForNetwork {
            for container in containers {
                if "\(container.id)-\(key)" == id {
                    return .container(container, networkKey: key)
                }
            }
        }
        return nil
    }
    
    var body: some View {
        buildTable(networks: networksStore.sortedFilteredNetworks)
        .tableStyle(.inset)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    creatingPopupIsVisible.toggle()
                }) {
                    SwiftUI.Image(systemName: "plus")
                }
                .buttonStyle(.glass)
                .popover(isPresented: $creatingPopupIsVisible) {
                    Form {
                        TextField(String(localized: "networkToCreateName"), text: $networkToCreate)
                        Button(action: {
                            Task {
                                do {
                                    creatingPopupIsVisible.toggle()
                                    try await networksStore.createNetwork(id: networkToCreate)
                                } catch {
                                    AppViewModel.shared.showError(.networkCreateFailed(error.localizedDescription))
                                }
                            }
                        }) {
                            Text(String(localized: "networkToCreate"))
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.regular)
                        .disabled(networkToCreate.isEmpty)
                    }
                    .formStyle(.grouped)
                    .frame(width: 400)
                    .padding(Spacing.sm)
                }
            }
        }
        .searchable(text: $networksStore.searchText, placement: .toolbar)
        .onChange(of: selection) { _, newValue in
            if let item = itemForID(newValue) {
                switch item {
                case .network:
                    selection = nil
                case .container(let container, _):
                    selection = nil
                    appViewModel.navigateTo(to: .detail(container: container))
                }
            }
        }
    }
    
    func buildTable(networks: [Network]) -> some View {
        Table(of: NetworkListItem.self, selection: $selection) {
            TableColumn("name") { item in
                switch item {
                case .network(let network):
                    Label(network.id, systemImage: "network")
                        .font(.callout)
                        .padding(.vertical, Spacing.xxs)
                case .container(let container, _):
                    Text(container.id)
                        .font(.callout)
                        .padding(.vertical, Spacing.xxs)
                        .foregroundColor(.secondary)
                }
            }
            TableColumn("ip") { item in
                switch item {
                case .network(_):
                    EmptyView()
                case .container(let container, let networkKey):
                    let attachment = container.container.networks.first { $0.network == networkKey }
                    Text(attachment.map { "\($0.ipv4Address)" } ?? "")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .monospaced()
                }
            }
            TableColumn("") { item in
                switch item {
                case .network:
                    EmptyView()
                case .container(let container, _):
                    ContainerActionsView(id: container.id)
                }
            }
            .width(100)
        } rows: {
            ForEach(networks) { key in
                if let networkItem = networkForKey(key.id) {
                    let childrenItems = childrenForNetwork(key.id)
                    
                    let isExpanded = expandedNetworks[key.id, default: true]
                    DisclosureTableRow(networkItem, isExpanded: Binding(
                        get: { isExpanded },
                        set: { expandedNetworks[key.id] = $0 }
                    )) {
                        ForEach(childrenItems, id: \.id) { childItem in
                            TableRow(childItem)
                        }
                    }
                }
            }
        }
    }
}

