//
//  ContainerDetailsInfoView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

private struct MetricRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.callout)
                .monospaced()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct ContainerDetailsInfoView: View {
    var container: ClientContainer
    var metrics: ContainerMetrics

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                containerDetailsCard
                if container.status == .running {
                    metricsCard
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var containerDetailsCard: some View {
        VStack(spacing: Spacing.md) {
            Label(container.id, systemImage: "shippingbox.fill")
                .font(.title3).fontWeight(.semibold)
                .monospaced()
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack(spacing: Spacing.xs) {
                Label {
                    Text(container.status.getDescription())
                } icon: {
                    SwiftUI.Image(systemName: container.status == .running ? "circle.fill" : "circle")
                        .foregroundStyle(container.status.getColor())
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: Spacing.xs) {
                Label("image", systemImage: "photo.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(container.configuration.image.reference)
                    .font(.callout)
                    .monospaced()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            Divider()

            HStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.xs) {
                    Label("cpus", systemImage: "cpu.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                    Text("\(container.configuration.resources.cpus) cores")
                        .font(.callout)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Spacing.xs) {
                    Label("memory", systemImage: "memorychip.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                    Text("\(container.configuration.resources.memoryInBytes / 1024 / 1024 / 1024) GiB")
                        .font(.callout)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if container.status == .running {
                runningSections
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.gray.withAlphaComponent(0.05))))
        .glassEffect(in: .rect(cornerRadius: 12))
    }

    @ViewBuilder
    private var runningSections: some View {
        if !container.networks.isEmpty {
            Divider()
            VStack(spacing: Spacing.xs) {
                Label("ips", systemImage: "network")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Color.accentColor)
                ForEach(container.networks, id: \.hostname) { network in
                    IPLabel(ip: "\(network.ipv4Address)", networkName: network.network)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        if !container.configuration.publishedPorts.isEmpty {
            Divider()
            VStack(spacing: Spacing.xs) {
                Label("ports", systemImage: "arrow.down.left.topright.rectangle.fill")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Color.accentColor)
                ForEach(container.configuration.publishedPorts, id: \.containerPort) { publishedPort in
                    PublishedPortLabel(hostPort: Int(publishedPort.hostPort), containerPort: Int(publishedPort.containerPort))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        if !container.configuration.publishedSockets.isEmpty {
            Divider()
            VStack(spacing: Spacing.xs) {
                Label("sockets", systemImage: "arrow.down.left.topright.rectangle.fill")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Color.accentColor)
                ForEach(container.configuration.publishedSockets, id: \.containerPath) { publishedSocket in
                    PublishedPathLabel(hostPath: publishedSocket.hostPath.absoluteString, containerPath: publishedSocket.containerPath.absoluteString)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        if !container.configuration.mounts.isEmpty {
            Divider()
            VStack(spacing: Spacing.xs) {
                Label("mounts", systemImage: "internaldrive.fill")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Color.accentColor)
                ForEach(container.configuration.mounts, id: \.destination) { mount in
                    PublishedPathLabel(hostPath: mountDisplaySource(mount), containerPath: mount.destination)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var metricsCard: some View {
        VStack(spacing: Spacing.md) {
            Label("Live Metrics", systemImage: "chart.bar.fill")
                .font(.title3).fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            if metrics.isAvailable {
                if let cpuPercent = metrics.cpuPercent {
                    MetricRow(icon: "gauge.with.needle.fill", label: "CPU", value: String(format: "%.1f%%", cpuPercent))
                }

                if let memUsage = metrics.memoryUsageBytes {
                    let memValue: String = {
                        if let memLimit = metrics.memoryLimitBytes {
                            return "\(DetailsViewModel.formatBytes(memUsage)) / \(DetailsViewModel.formatBytes(memLimit))"
                        }
                        return DetailsViewModel.formatBytes(memUsage)
                    }()
                    MetricRow(icon: "memorychip.fill", label: "Memory", value: memValue)
                }

                if let rxBytes = metrics.networkRxBytes {
                    MetricRow(icon: "arrow.down.circle.fill", label: "Network RX", value: DetailsViewModel.formatBytes(rxBytes))
                }

                if let txBytes = metrics.networkTxBytes {
                    MetricRow(icon: "arrow.up.circle.fill", label: "Network TX", value: DetailsViewModel.formatBytes(txBytes))
                }

                if let readBytes = metrics.blockReadBytes {
                    MetricRow(icon: "arrow.down.doc.fill", label: "Block Read", value: DetailsViewModel.formatBytes(readBytes))
                }

                if let writeBytes = metrics.blockWriteBytes {
                    MetricRow(icon: "arrow.up.doc.fill", label: "Block Write", value: DetailsViewModel.formatBytes(writeBytes))
                }

                if let numProcs = metrics.numProcesses {
                    MetricRow(icon: "list.number", label: "Processes", value: "\(numProcs)")
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(Spacing.md)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.gray.withAlphaComponent(0.05))))
        .glassEffect(in: .rect(cornerRadius: 12))
    }
}
