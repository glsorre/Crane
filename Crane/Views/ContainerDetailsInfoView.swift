//
//  ContainerDetailsInfoView.swift
//  Crane
//

import ContainerResource
import SwiftUI

private struct MetricRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, Spacing.xs)
    }
}

struct ContainerDetailsInfoView: View {
    var snapshot: ContainerSnapshot
    var metrics: ContainerMetrics

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                containerDetailsCard
                
                if snapshot.status == .running {
                    metricsDashboard
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.xxs)
        }
    }

    private var containerDetailsCard: some View {
        VStack(spacing: Spacing.md) {
            // Status and Header
            HStack(spacing: Spacing.xs) {
                Label {
                    Text(snapshot.status.getDescription())
                        .fontWeight(.semibold)
                } icon: {
                    GlowingStatusDot(
                        color: snapshot.status.getColor(),
                        isAnimated: snapshot.status == .running
                    )
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: Spacing.xs) {
                Label("image", systemImage: "photo.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 80, alignment: .leading)
                
                Spacer()
                
                Text(snapshot.configuration.image.reference)
                    .font(.callout)
                    .monospaced()
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.xs) {
                    Label("cpus", systemImage: "cpu.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                    Text("\(snapshot.configuration.resources.cpus) cores")
                        .font(.callout)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Spacing.xs) {
                    Label("memory", systemImage: "memorychip.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                    Text("\(snapshot.configuration.resources.memoryInBytes / 1024 / 1024 / 1024) GiB")
                        .font(.callout)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if snapshot.status == .running {
                runningSections
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.windowBackgroundColor).opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var runningSections: some View {
        if !snapshot.networks.isEmpty {
            Divider()
            VStack(spacing: Spacing.xs) {
                Label("ips", systemImage: "network")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Color.accentColor)
                ForEach(snapshot.networks, id: \.hostname) { network in
                    IPLabel(ip: "\(network.ipv4Address)", networkName: network.network)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        if !snapshot.configuration.publishedPorts.isEmpty {
            Divider()
            VStack(spacing: Spacing.xs) {
                Label("ports", systemImage: "arrow.down.left.topright.rectangle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Color.accentColor)
                ForEach(snapshot.configuration.publishedPorts, id: \.containerPort) { publishedPort in
                    PublishedPortLabel(hostPort: Int(publishedPort.hostPort), containerPort: Int(publishedPort.containerPort))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        if !snapshot.configuration.publishedSockets.isEmpty {
            Divider()
            VStack(spacing: Spacing.xs) {
                Label("sockets", systemImage: "arrow.down.left.topright.rectangle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Color.accentColor)
                ForEach(snapshot.configuration.publishedSockets, id: \.containerPath) { publishedSocket in
                    PublishedPathLabel(
                        hostPath: publishedSocket.hostPath.absoluteString, containerPath: publishedSocket.containerPath.absoluteString
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }

        if !snapshot.configuration.mounts.isEmpty {
            Divider()
            VStack(spacing: Spacing.xs) {
                Label("mounts", systemImage: "internaldrive.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Color.accentColor)
                ForEach(snapshot.configuration.mounts, id: \.destination) { mount in
                    PublishedPathLabel(hostPath: mountDisplaySource(mount), containerPath: mount.destination)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var metricsDashboard: some View {
        VStack(spacing: Spacing.md) {
            Label("Live Metrics", systemImage: "chart.bar.fill")
                .font(.title3).fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            if metrics.isAvailable {
                // Side-by-side Progress Gauges
                HStack(spacing: Spacing.md) {
                    let cpuVal = min(max((metrics.cpuPercent ?? 0.0) / 100.0, 0.0), 1.0)
                    MetricGaugeView(
                        title: "CPU Usage",
                        value: cpuVal,
                        displayString: String(format: "%.1f%%", metrics.cpuPercent ?? 0.0),
                        color: .green
                    )

                    let memLimit = max(metrics.memoryLimitBytes ?? 1, 1)
                    let memUsage = metrics.memoryUsageBytes ?? 0
                    let memRatio = min(max(Double(memUsage) / Double(memLimit), 0.0), 1.0)
                    MetricGaugeView(
                        title: "Memory",
                        value: memRatio,
                        displayString: String(format: "%.1f%%", memRatio * 100.0),
                        color: .blue
                    )
                }

                // Side-by-side Real-time Sparklines
                HStack(spacing: Spacing.md) {
                    // CPU Sparkline
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("CPU History (Live)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        SparklineChartView(
                            data: metrics.cpuHistory,
                            maxBound: 100.0,
                            strokeColor: .green
                        )
                        .frame(height: 70)
                        .padding(.top, Spacing.xs)
                    }
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.controlBackgroundColor).opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )

                    // Memory Sparkline
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Memory History (Live)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        SparklineChartView(
                            data: metrics.memHistory,
                            maxBound: 100.0,
                            strokeColor: .blue
                        )
                        .frame(height: 70)
                        .padding(.top, Spacing.xs)
                    }
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.controlBackgroundColor).opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                }

                // Lower Info Grid
                VStack(spacing: 0) {
                    if let rxBytes = metrics.networkRxBytes {
                        MetricRow(icon: "arrow.down.circle.fill", label: "Network RX", value: DetailsViewModel.formatBytes(rxBytes))
                    }

                    if let txBytes = metrics.networkTxBytes {
                        Divider()
                        MetricRow(icon: "arrow.up.circle.fill", label: "Network TX", value: DetailsViewModel.formatBytes(txBytes))
                    }

                    if let readBytes = metrics.blockReadBytes {
                        Divider()
                        MetricRow(icon: "arrow.down.doc.fill", label: "Block Read", value: DetailsViewModel.formatBytes(readBytes))
                    }

                    if let writeBytes = metrics.blockWriteBytes {
                        Divider()
                        MetricRow(icon: "arrow.up.doc.fill", label: "Block Write", value: DetailsViewModel.formatBytes(writeBytes))
                    }

                    if let numProcs = metrics.numProcesses {
                        Divider()
                        MetricRow(icon: "list.number", label: "Active Processes", value: "\(numProcs)")
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.controlBackgroundColor).opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(Spacing.md)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.windowBackgroundColor).opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
