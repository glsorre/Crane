//
//  CraneVolumesListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 08/02/26.
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

enum VolumeListItem {
    case volume(CraneVolume)
    case container(Container, volumeName: String)

    static var sortOrderComparator: KeyPathComparator<VolumeListItem> {
        .init(\.id, order: .forward)
    }

    var id: String {
        switch self {
        case .volume(let volume):
            return volume.id
        case .container(let container, let volumeName):
            return "\(container.id)-\(volumeName)"
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
    @State private var appViewModel = AppViewModel.shared
    @State private var volumesStore = VolumesStore.shared
    @State private var selection: VolumeListItem.ID? = nil
    @State private var expandedVolumes: [String: Bool] = [:]

    @State private var creatingPopupIsVisible: Bool = false
    @State private var volumeToCreate: String = ""

    private func volumeForKey(_ key: String) -> VolumeListItem? {
        guard let volume = volumesStore.volumes.first(where: { $0.id == key }) else {
            return nil
        }
        return .volume(volume)
    }

    private func childrenForVolume(_ key: String) -> [VolumeListItem] {
        let containers = ContainersStore.shared.containersForVolume[key] ?? []
        return containers.map { .container($0, volumeName: key) }
    }

    private func itemForID(_ id: VolumeListItem.ID?) -> VolumeListItem? {
        guard let id = id else { return nil }
        for volume in volumesStore.volumes {
            if volume.id == id {
                return .volume(volume)
            }
        }
        for (key, containers) in ContainersStore.shared.containersForVolume {
            for container in containers {
                if "\(container.id)-\(key)" == id {
                    return .container(container, volumeName: key)
                }
            }
        }
        return nil
    }

    var body: some View {
        buildTable(volumes: volumesStore.sortedFilteredVolumes)
        .tableStyle(.inset)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    Task {
                        await volumesStore.pruneVolumes()
                    }
                }) {
                    SwiftUI.Image(systemName: "xmark.bin")
                }
                .buttonStyle(.glass)
                .disabled(!volumesStore.hasUnusedVolumes)
                .help("Remove unused volumes")
            }
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    creatingPopupIsVisible.toggle()
                }) {
                    SwiftUI.Image(systemName: "plus")
                }
                .buttonStyle(.glass)
                .popover(isPresented: $creatingPopupIsVisible) {
                    Form {
                        TextField(String(localized: "volumeToCreateName"), text: $volumeToCreate)
                        Button(action: {
                            Task {
                                do {
                                    creatingPopupIsVisible.toggle()
                                    try await volumesStore.createVolume(name: volumeToCreate)
                                } catch {
                                    AppViewModel.shared.showError(.volumeCreateFailed(error.localizedDescription))
                                }
                            }
                        }) {
                            Text(String(localized: "volumeToCreate"))
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.regular)
                        .disabled(volumeToCreate.isEmpty)
                    }
                    .formStyle(.grouped)
                    .frame(width: 400)
                    .padding(Spacing.sm)
                }
            }
        }
        .searchable(text: $volumesStore.searchText, placement: .toolbar)
        .onChange(of: selection) { _, newValue in
            if let item = itemForID(newValue) {
                switch item {
                case .volume:
                    selection = nil
                case .container(let container, _):
                    selection = nil
                    appViewModel.navigateTo(to: .detail(container: container))
                }
            }
        }
    }

    func buildTable(volumes: [CraneVolume]) -> some View {
        Table(of: VolumeListItem.self, selection: $selection) {
            TableColumn("name") { item in
                switch item {
                case .volume(let volume):
                    Label(volume.id, systemImage: "externaldrive.fill")
                        .font(.callout)
                        .padding(.vertical, Spacing.xxs)
                case .container(let container, _):
                    Text(container.id)
                        .font(.callout)
                        .padding(.vertical, Spacing.xxs)
                        .foregroundColor(.secondary)
                }
            }
            TableColumn("driver") { item in
                switch item {
                case .volume(let volume):
                    Text(volume.volume.driver)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .monospaced()
                case .container(let container, let volumeName):
                    let destination = container.container.configuration.mounts
                        .first { $0.isVolume && $0.volumeName == volumeName }?.destination
                    Text(destination ?? "")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .monospaced()
                }
            }
            TableColumn("") { item in
                switch item {
                case .volume(let volume):
                    let isEmpty = (ContainersStore.shared.containersForVolume[volume.id] ?? []).isEmpty
                    if isEmpty {
                        SpinnerButton(isLoading: volume.transiting) {
                            Task {
                                await volumesStore.removeVolume(name: volume.id)
                            }
                        } label: {
                            SwiftUI.Image(systemName: "trash.fill")
                                .font(Font.system(size: 11))
                        }
                        .buttonStyle(.glass)
                        .foregroundColor(Color(.systemRed))
                        .frame(width: 50)
                    }
                case .container(let container, _):
                    ContainerActionsView(id: container.id)
                }
            }
            .width(100)
        } rows: {
            ForEach(volumes) { key in
                if let volumeItem = volumeForKey(key.id) {
                    let childrenItems = childrenForVolume(key.id)

                    let isExpanded = expandedVolumes[key.id, default: true]
                    DisclosureTableRow(volumeItem, isExpanded: Binding(
                        get: { isExpanded },
                        set: { expandedVolumes[key.id] = $0 }
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
