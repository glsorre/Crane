//
//  VolumeRowView.swift
//  Crane
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct VolumeRowView: View {
    @Environment(\.craneStores) private var stores
    private var containersStore: ContainersStore { stores.containers }
    private var volumesStore: VolumesStore { stores.volumes }
    @State private var isExpanded: Bool = false
    var volume: CraneVolume

    private var children: [Container] {
        containersStore.containersForVolume[volume.id] ?? []
    }

    var body: some View {
        Group {
            if children.isEmpty {
                labelRow
            } else {
                DisclosureGroup(isExpanded: $isExpanded) {
                    ForEach(children) { container in
                        AttachedContainerListRow(
                            container: container,
                            detail: volumeMountDetailString(container: container)
                        )
                    }
                } label: {
                    labelRow
                }
            }
        }
    }

    private func volumeMountDetailString(container: Container) -> String? {
        guard let mount = container.snapshot.configuration.mounts
            .first(where: { $0.isVolume && $0.volumeName == volume.id })
        else { return nil }
        return "\(mount.destination)"
    }

    private var labelRow: some View {
        ResourceListRow(
            title: volume.id,
            subtitle: subtitle,
            leading: {
                SwiftUI.Image(systemName: "externaldrive.fill")
                    .foregroundStyle(.secondary)
            },
            trailing: {
                if children.isEmpty {
                    RowActionButton(
                        .destructive,
                        isLoading: volume.transiting,
                        action: {
                            Task { await volumesStore.removeVolume(name: volume.id) }
                        },
                        label: {
                            SwiftUI.Image(systemName: "trash.fill")
                        }
                    )
                }
            }
        )
    }

    private var subtitle: String {
        let count = children.count
        let attached: String
        if count == 0 {
            attached = String(localized: "volumeMountedNone")
        } else if count == 1 {
            attached = String(localized: "volumeMountedOne")
        } else {
            attached = String(format: String(localized: "volumeMountedMany"), count)
        }
        return "\(volume.volume.driver) \u{00B7} \(attached)"
    }
}
