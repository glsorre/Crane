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
    @Bindable var viewModel: CraneViewModel
    var id: String
    
    var body: some View {
        let container = viewModel.containers![id]
        
        if container != nil {
            VStack(spacing: 20) {
                Text(id)
                    .font(.largeTitle)
                HStack(spacing: 10) {
                    Label("cpus", systemImage: "cpu.fill")
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .foregroundStyle(Color.accentColor)
                    Text("\(container!.configuration.resources.cpus)")
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                
                HStack(spacing: 10) {
                    Label("memory", systemImage: "memorychip.fill")
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .foregroundStyle(Color.accentColor)
                    Text("\(container!.configuration.resources.memoryInBytes / 1024 / 1024 / 1024) GiB")
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                
                if container!.status == .running {
                    if !container!.networks.isEmpty {
                        VStack(spacing: 10) {
                            Label("ips", systemImage: "cabinet.fill")
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .foregroundStyle(Color.accentColor)
                            ForEach(container!.networks, id: \.hostname) { network in
                                Text("\(network.address)")
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                        }
                    }
                    
                    if !container!.configuration.publishedPorts.isEmpty {
                        VStack(spacing: 10) {
                            Label("ports", systemImage: "arrow.down.left.topright.rectangle.fill")
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .foregroundStyle(Color.accentColor)
                            ForEach(container!.configuration.publishedPorts, id: \PublishPort.containerPort) { publishedPort in
                                Text("\(String(Int(publishedPort.hostPort))):\(String(Int(publishedPort.containerPort)))")
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                        }
                    }
                    
                    if !container!.configuration.publishedSockets.isEmpty {
                        VStack(spacing: 10) {
                            Label("sockets", systemImage: "arrow.down.left.topright.rectangle.fill")
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .foregroundStyle(Color.accentColor)
                            ForEach(container!.configuration.publishedSockets, id: \.containerPath) { publishedSocket in
                                Text("\(publishedSocket.hostPath):\(publishedSocket.containerPath)")
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                            }
                        }
                    }
                }
                Spacer()
            }
            .frame(maxWidth: 200, alignment: .topLeading) 
            .padding()
        } else {
            EmptyView()
        }
    }
}
