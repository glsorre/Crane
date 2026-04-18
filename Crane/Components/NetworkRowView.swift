//
//  NetworkRowView.swift
//  Crane
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct NetworkRowView: View {
    @State private var appViewModel = AppViewModel.shared
    @State private var containersStore = ContainersStore.shared
    @State private var networksStore = NetworksStore.shared
    @State private var isExpanded: Bool = true
    var network: Network

    private var children: [Container] {
        containersStore.containersForNetwork[network.id] ?? []
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(children) { container in
                HStack {
                    Circle()
                        .fill(container.isExited ? .secondary : container.snapshot.status.getColor())
                        .frame(width: 8, height: 8)

                    Text(container.id)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let attachment = container.snapshot.networks.first(where: { $0.network == network.id }) {
                        Text("\(attachment.ipv4Address)")
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
        .padding(.vertical, Spacing.xxs)
    }
}
