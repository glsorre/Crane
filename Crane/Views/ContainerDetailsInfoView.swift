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
        VStack(spacing: 20) {
            Text(container.id)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                Label("cpus", systemImage: "cpu.fill")
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .foregroundStyle(Color.accentColor)
                Text("\(container.configuration.resources.cpus) cores")
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            
            HStack(spacing: 10) {
                Label("memory", systemImage: "memorychip.fill")
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .foregroundStyle(Color.accentColor)
                Text("\(container.configuration.resources.memoryInBytes / 1024 / 1024 / 1024) GiB")
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            
            if container.status == .running {
                if !container.networks.isEmpty {
                    VStack(spacing: 10) {
                        Label("ips", systemImage: "cabinet.fill")
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .foregroundStyle(Color.accentColor)
                        ForEach(container.networks, id: \.hostname) { network in
                            Text("\(network.ipv4Address)")
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .monospaced()
                        }
                    }
                }
                
                if !container.configuration.publishedPorts.isEmpty {
                    VStack(spacing: 10) {
                        Label("ports", systemImage: "arrow.down.left.topright.rectangle.fill")
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .foregroundStyle(Color.accentColor)
                        ForEach(container.configuration.publishedPorts, id: \.containerPort) { publishedPort in
                            PublishedPortLabel(hostPort: Int(publishedPort.hostPort), containerPort: Int(publishedPort.containerPort))
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }
                
                if !container.configuration.publishedSockets.isEmpty {
                    VStack(spacing: 10) {
                        Label("sockets", systemImage: "arrow.down.left.topright.rectangle.fill")
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .foregroundStyle(Color.accentColor)
                        ForEach(container.configuration.publishedSockets, id: \.containerPath) { publishedSocket in
                            PublishedPathLabel(hostPath: publishedSocket.hostPath.absoluteString, containerPath: publishedSocket.containerPath.absoluteString)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }
                
                if !container.configuration.mounts.isEmpty {
                    VStack(spacing: 10) {
                        Label("mounts", systemImage: "internaldrive.fill")
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
        .frame(maxWidth: 200, alignment: .topLeading)
        .padding()
    }
}
