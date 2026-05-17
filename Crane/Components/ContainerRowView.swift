//
//  ContainerRowView.swift
//  Crane
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct ContainerRowView: View {
    @State private var containersStore = ContainersStore.shared
    var container: Container

    var body: some View {
        ResourceListRow(
            title: container.id,
            subtitle: metadataSummary,
            leading: {
                Circle()
                    .fill(container.isExited ? .secondary : container.snapshot.status.getColor())
                    .frame(width: 8, height: 8)
            },
            trailing: {
                ContainerActionsView(id: container.id)
            }
        )
    }

    private var metadataSummary: String {
        var parts: [String] = []

        let cpus = container.snapshot.configuration.resources.cpus
        let memGiB = container.snapshot.configuration.resources.memoryInBytes / 1024 / 1024 / 1024
        parts.append("\(cpus) CPUs \u{00B7} \(memGiB) GiB")

        let attachedNetworks = container.snapshot.networks
        if let firstAttachedNetwork = attachedNetworks.first {
            if attachedNetworks.count == 1 {
                parts.append("\(firstAttachedNetwork.network) (\(firstAttachedNetwork.ipv4Address))")
            } else {
                parts.append("\(attachedNetworks.count) networks")
            }
        } else {
            let configuredNetworks = container.snapshot.configuration.networks
            if let firstConfiguredNetwork = configuredNetworks.first {
                if configuredNetworks.count == 1 {
                    parts.append(firstConfiguredNetwork.network)
                } else {
                    parts.append("\(configuredNetworks.count) networks")
                }
            }
        }

        if container.snapshot.status == .running {
            let portCount = container.snapshot.configuration.publishedPorts.count
            if portCount > 0 {
                parts.append("\(portCount) port\(portCount == 1 ? "" : "s")")
            }

            let socketCount = container.snapshot.configuration.publishedSockets.count
            if socketCount > 0 {
                parts.append("\(socketCount) socket\(socketCount == 1 ? "" : "s")")
            }
        }

        let mountCount = container.snapshot.configuration.mounts.count
        if mountCount > 0 {
            parts.append("\(mountCount) mount\(mountCount == 1 ? "" : "s")")
        }

        return parts.joined(separator: " \u{00B7} ")
    }
}
