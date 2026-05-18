//
//  NetworkRowView.swift
//  Crane
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct NetworkRowView: View {
    @Environment(\.craneStores) private var stores
    private var containersStore: ContainersStore { stores.containers }
    private var networksStore: NetworksStore { stores.networks }
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
    }

    private func networkDetailString(container: Container) -> String? {
        guard let attachment = container.snapshot.networks.first(where: { $0.network == network.id }) else {
            return nil
        }
        return "\(attachment.ipv4Address)"
    }

    private var labelRow: some View {
        ResourceListRow(
            title: network.id,
            subtitle: subtitle,
            leading: {
                SwiftUI.Image(systemName: "network")
                    .foregroundStyle(.secondary)
            },
            trailing: {
                if !network.network.isBuiltin && children.isEmpty {
                    RowActionButton(
                        .destructive,
                        isLoading: network.transiting,
                        action: {
                            Task { await networksStore.removeNetwork(id: network.id) }
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
        let kind: String = network.network.isBuiltin
            ? String(localized: "networkKindBuiltin")
            : String(localized: "networkKindUser")
        let count = children.count
        let attached: String
        if count == 0 {
            attached = String(localized: "networkAttachedNone")
        } else if count == 1 {
            attached = String(localized: "networkAttachedOne")
        } else {
            attached = String(format: String(localized: "networkAttachedMany"), count)
        }
        return "\(kind) \u{00B7} \(attached)"
    }
}
