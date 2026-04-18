//
//  VolumeRowView.swift
//  Crane
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct VolumeRowView: View {
    @State private var containersStore = ContainersStore.shared
    @State private var volumesStore = VolumesStore.shared
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
        .padding(.vertical, Spacing.xxs)
    }

    private func volumeMountDetailString(container: Container) -> String? {
        guard let mount = container.snapshot.configuration.mounts
            .first(where: { $0.isVolume && $0.volumeName == volume.id })
        else { return nil }
        return "\(mount.destination)"
    }

    private var labelRow: some View {
        HStack {
            SwiftUI.Image(systemName: "externaldrive.fill")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(volume.id)
                    .font(.headline)

                Text(volume.volume.driver)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if children.isEmpty {
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
        }
    }
}
