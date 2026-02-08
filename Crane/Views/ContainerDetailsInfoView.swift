//
//  ContainerDetailsInfoView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct ContainerDetailsInfoView: View {
    var container: ClientContainer
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            Text(container.id)
                .font(.title3).fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            HStack(spacing: Spacing.xs) {
                Label("cpus", systemImage: "cpu.fill")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .foregroundStyle(Color.accentColor)
                Text("\(container.configuration.resources.cpus) cores")
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            HStack(spacing: Spacing.xs) {
                Label("memory", systemImage: "memorychip.fill")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .foregroundStyle(Color.accentColor)
                Text("\(container.configuration.resources.memoryInBytes / 1024 / 1024 / 1024) GiB")
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            if container.status == .running {
                if !container.networks.isEmpty {
                    Divider()
                    VStack(spacing: Spacing.xs) {
                        Label("ips", systemImage: "cabinet.fill")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .foregroundStyle(Color.accentColor)
                        ForEach(container.networks, id: \.hostname) { network in
                            Text("\(network.ipv4Address)")
                                .font(.callout)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .monospaced()
                        }
                    }
                }

                if !container.configuration.publishedPorts.isEmpty {
                    Divider()
                    VStack(spacing: Spacing.xs) {
                        Label("ports", systemImage: "arrow.down.left.topright.rectangle.fill")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .foregroundStyle(Color.accentColor)
                        ForEach(container.configuration.publishedPorts, id: \.containerPort) { publishedPort in
                            PublishedPortLabel(hostPort: Int(publishedPort.hostPort), containerPort: Int(publishedPort.containerPort))
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }

                if !container.configuration.publishedSockets.isEmpty {
                    Divider()
                    VStack(spacing: Spacing.xs) {
                        Label("sockets", systemImage: "arrow.down.left.topright.rectangle.fill")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .foregroundStyle(Color.accentColor)
                        ForEach(container.configuration.publishedSockets, id: \.containerPath) { publishedSocket in
                            PublishedPathLabel(hostPath: publishedSocket.hostPath.absoluteString, containerPath: publishedSocket.containerPath.absoluteString)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }

                if !container.configuration.mounts.isEmpty {
                    Divider()
                    VStack(spacing: Spacing.xs) {
                        Label("mounts", systemImage: "internaldrive.fill")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .foregroundStyle(Color.accentColor)
                        ForEach(container.configuration.mounts, id: \.destination) { mount in
                            PublishedPathLabel(hostPath: mountDisplaySource(mount), containerPath: mount.destination)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }
            }
            Spacer()
        }
        .frame(minWidth: 200, idealWidth: 240, maxWidth: 280, alignment: .topLeading)
        .padding(Spacing.md)
        .glassEffect(in: .rect(cornerRadius: 12))
    }
}
