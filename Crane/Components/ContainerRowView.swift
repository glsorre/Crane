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
        VStack(alignment: .leading, spacing: Spacing.xxxs) {
            // Line 1: status dot + name + actions
            HStack {
                Circle()
                    .fill(container.isExited ? .secondary : container.container.status.getColor())
                    .frame(width: 8, height: 8)

                Text(container.id)
                    .font(.headline)

                Spacer()

                ContainerActionsView(id: container.id)
            }

            // Line 2: metadata summary
            HStack(spacing: Spacing.xxs) {
                Text(metadataSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    private var metadataSummary: String {
        var parts: [String] = []

        let cpus = container.container.configuration.resources.cpus
        let memGiB = container.container.configuration.resources.memoryInBytes / 1024 / 1024 / 1024
        parts.append("\(cpus) CPUs \u{00B7} \(memGiB) GiB")

        let networks = container.container.networks
        if let first = networks.first {
            if networks.count == 1 {
                parts.append("\(first.network) (\(first.ipv4Address))")
            } else {
                parts.append("\(networks.count) networks")
            }
        }

        if container.container.status == .running {
            let portCount = container.container.configuration.publishedPorts.count
            if portCount > 0 {
                parts.append("\(portCount) port\(portCount == 1 ? "" : "s")")
            }

            let socketCount = container.container.configuration.publishedSockets.count
            if socketCount > 0 {
                parts.append("\(socketCount) socket\(socketCount == 1 ? "" : "s")")
            }
        }

        let mountCount = container.container.configuration.mounts.count
        if mountCount > 0 {
            parts.append("\(mountCount) mount\(mountCount == 1 ? "" : "s")")
        }

        return parts.joined(separator: " \u{00B7} ")
    }
}
