//
//  CraneVolumesListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerClient
import ContainerNetworkService
import SwiftUI

enum VolumeListItem {
    case container(ClientContainer)
    case volume(Volume, containerId: String)
    
    static var sortOrderComparator: KeyPathComparator<VolumeListItem> {
        .init(\.id, order: .forward)
    }
    
    var id: String {
        switch self {
        case .container(let container):
            return container.id
        case .volume(let volume, let containerId):
            return "\(containerId)-\(volume.name)"
        }
    }
}

extension VolumeListItem: Identifiable {}

extension VolumeListItem: Hashable {
    static func == (lhs: VolumeListItem, rhs: VolumeListItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct CraneVolumesListView: View {
    @Bindable var viewModel: CraneViewModel
    @State private var selection: VolumeListItem.ID? = nil
    @State private var expandedContainers: [String: Bool] = [:]
    
    private var sortedFilteredVolumes: [(String, [Volume])] {
        let rawSorted = viewModel.volumesForContainer.sorted { $0.key < $01.key }
        if viewModel.searchText.isEmpty {
            return rawSorted.map { ($0.key, $0.value) }
        } else {
            return rawSorted.filter { containerId, volumes in
                containerId.contains(viewModel.searchText) || volumes.contains { $0.name.contains(viewModel.searchText) }
            }.map { ($0.key, $0.value) }
        }
    }
    
    private func containerForId(_ containerId: String) -> VolumeListItem? {
        if let container = viewModel.containers?[containerId] {
            return .container(container)
        }
        return nil
    }
    
    private func volumesForContainer(_ containerId: String) -> [VolumeListItem] {
        return viewModel.volumesForContainer[containerId]?.map { .volume($0, containerId: containerId) } ?? []
    }
    
    private func itemForID(_ id: VolumeListItem.ID?) -> VolumeListItem? {
        guard let id = id else { return nil }
        let raw = viewModel.volumesForContainer
        for (containerId, volumes) in raw {
            if let container = viewModel.containers?[containerId],
               containerId == id {
                    return .container(container)
            }
            for volume in volumes {
                if "\(containerId)-\(volume.name)" == id {
                    return .volume(volume, containerId: containerId)
                }
            }
        }
        return nil
    }
    
    var body: some View {
        Table(of: VolumeListItem.self, selection: $selection) {
            TableColumn("name") { item in
                switch item {
                case .volume(let volume, _):
                    Label(volume.name, systemImage: "internaldrive.fill")
                        .padding(5)
                case .container(let container):
                    Label(container.id, systemImage: "desktopcomputer")
                        .padding(5)
                        .foregroundColor(.secondary)
                }
            }
            TableColumn("imagePath") {item in
                switch item {
                case .volume(let volume, _):
                    Text(viewModel.volumes![volume.name]!.source)
                        .monospaced()
                        .padding(5)
                case .container:
                    EmptyView()
                }
            }
            TableColumn("mountPoint") {item in
                switch item {
                case .volume(let volume, let containerId):
                    let mountPoint = viewModel.containers![containerId]!.configuration.mounts.first(where: { $0.volumeName == volume.name })!.destination
                    Text(mountPoint)
                        .monospaced()
                        .padding(5)
                case .container:
                    EmptyView()
                }
            }
        } rows: {
            ForEach(sortedFilteredVolumes, id: \.0) { containerId, _ in
                if let networkItem = containerForId(containerId) {
                    let childrenItems = volumesForContainer(containerId)
                    
                    let isExpanded = expandedContainers[containerId, default: true]
                    DisclosureTableRow(networkItem, isExpanded: Binding(
                        get: { isExpanded },
                        set: { expandedContainers[containerId] = $0 }
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
                case .volume:
                    selection = nil
                case .container(let container):
                    selection = nil
                    viewModel.path.append(CraneRoute.detail(id: container.id))
                }
            }
        }
    }
}

