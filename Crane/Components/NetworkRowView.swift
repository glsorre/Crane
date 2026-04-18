//
//  NetworkRowView.swift
//  Crane
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct NetworkRowView: View {
    @State private var containersStore = ContainersStore.shared
    @State private var networksStore = NetworksStore.shared
    @State private var isExpanded: Bool = false
    var network: Network

    private var children: [Container] {
        containersStore.containersForNetwork[network.id] ?? []
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
                            detail: networkDetailString(container: container)
                        )
                    }
                } label: {
                    labelRow
                }
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    private func networkDetailString(container: Container) -> String? {
        guard let attachment = container.snapshot.networks.first(where: { $0.network == network.id }) else {
            return nil
        }
        return "\(attachment.ipv4Address)"
    }

    private var labelRow: some View {
        HStack {
            SwiftUI.Image(systemName: "network")
                .foregroundStyle(.secondary)

            Text(network.id)
                .font(.headline)

            Spacer()

            if !network.network.isBuiltin && children.isEmpty {
                SpinnerButton(isLoading: network.transiting) {
                    Task {
                        await networksStore.removeNetwork(id: network.id)
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
