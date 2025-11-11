//
//  ContainerDetailsInfoView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerClient
import ContainerNetworkService
import SwiftUI

struct ContainerDetailsInfoView: View {
    @Binding var viewModel: ViewModel
    let container: ClientContainer
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Label("CPUs", systemImage: "cpu.fill")
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .foregroundStyle(Color.accentColor)
                Text("\(container.configuration.resources.cpus)")
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            
            VStack(spacing: 10) {
                Label("Memory", systemImage: "memorychip.fill")
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .foregroundStyle(Color.accentColor)
                Text("\(container.configuration.resources.memoryInBytes / 1024 / 1024) MB")
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            
            if container.status == .running {
                if !container.networks.isEmpty {
                    VStack(spacing: 10) {
                        Label("IPs", systemImage: "cabinet.fill")
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .foregroundStyle(Color.accentColor)
                        ForEach(container.networks, id: \.network) { network in
                            Text("\(network.address)")
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }
                
                if !container.configuration.publishedPorts.isEmpty {
                    VStack(spacing: 10) {
                        Label("Ports", systemImage: "arrow.down.left.topright.rectangle.fill")
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .foregroundStyle(Color.accentColor)
                        ForEach(container.configuration.publishedPorts, id: \PublishPort.containerPort) { publishedPort in
                            Text("\(String(Int(publishedPort.hostPort))):\(String(Int(publishedPort.containerPort)))")
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }
                
                if !container.configuration.publishedSockets.isEmpty {
                    VStack(spacing: 10) {
                        Label("Sockets", systemImage: "arrow.down.left.topright.rectangle.fill")
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .foregroundStyle(Color.accentColor)
                        ForEach(container.configuration.publishedSockets, id: \.containerPath) { publishedSocket in
                            Text("\(publishedSocket.hostPath):\(publishedSocket.containerPath)")
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }
            }
            Spacer()
        }
        .fixedSize(horizontal: true, vertical: false)
        .padding()
    }
}

