//
//  VolumeRowView.swift
//  Crane
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct VolumeRowView: View {
    @State private var appViewModel = AppViewModel.shared
    @State private var containersStore = ContainersStore.shared
    @State private var volumesStore = VolumesStore.shared
    @State private var isExpanded: Bool = true
    var volume: CraneVolume

    private var children: [Container] {
        containersStore.containersForVolume[volume.id] ?? []
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(children) { container in
                HStack {
                    Circle()
                        .fill(container.isExited ? .secondary : container.container.status.getColor())
                        .frame(width: 8, height: 8)

                    Text(container.id)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let mount = container.container.configuration.mounts
                        .first(where: { $0.isVolume && $0.volumeName == volume.id }) {
                        Text(mount.destination)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospaced()
                    }

                    Spacer()

                    ContainerActionsView(id: container.id)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    appViewModel.navigateTo(to: .detail(container: container))
                }
            }
        } label: {
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
        .padding(.vertical, Spacing.xxs)
    }
}
