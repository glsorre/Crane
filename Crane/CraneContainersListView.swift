//
//  CraneContainersListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerClient
import ContainerNetworkService
import SwiftUI

struct CraneContainersListView: View {
    @Bindable var viewModel: CraneViewModel
    @State private var sortOrder = [KeyPathComparator(\ClientContainer.id, order: .forward)]
    @State private var selection: ClientContainer.ID?
    
    var body: some View {
        let sortedFilteredContainers = viewModel.searchText.isEmpty ?
            viewModel.containers?.values.sorted { $0.id < $1.id } ?? [] :
            viewModel.containers?.values.sorted { $0.id < $1.id }.filter { $0.id.contains(viewModel.searchText) } ?? []
        
        Table(of: ClientContainer.self, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("name", value: \.id) { container in
                Text(container.id)
                    .padding(.vertical, 5)
            }
            TableColumn("status", value: \.status.rawValue) { container in
                Image(systemName: container.status.getIcon())
                    .padding(.vertical, 5)
            }.width(60)
            TableColumn("cpus", value: \.configuration.resources.cpus) { container in
                Text(String(container.configuration.resources.cpus))
                    .padding(.vertical, 5)
            }.width(80)
            
            TableColumn("memory", value: \.configuration.resources.memoryInBytes) { container in
                let memoryInGiB = container.configuration.resources.memoryInBytes / 1024 / 1024 / 1024
                Text("\(memoryInGiB) GiB")
                    .padding(.vertical, 5)
            }.width(80)
            
            TableColumn("networks", value: \.networks.count) { container in
                if (container.status == .running) {
                    ForEach(container.networks, id: \.network) {network in
                        Text(network.network)
                    }
                }
            }
            TableColumn("ips", value: \.networks.count) { container in
                if (container.status == .running) {
                    ForEach(container.networks, id: \.network) {network in
                        Text(network.address)
                            .monospaced()
                    }
                }
            }
            TableColumn("ports", value: \.configuration.publishedPorts.count) { container in
                if (container.status == .running) {
                    ForEach(container.configuration.publishedPorts, id: \.containerPort) {publishedPort in
                        PublishedPortLabel(hostPort: publishedPort.hostPort, containerPort: publishedPort.containerPort)
                    }
                }
            }
            TableColumn("sockets", value: \.configuration.publishedSockets.count) { container in
                if (container.status == .running) {
                    ForEach(container.configuration.publishedSockets, id: \.containerPath) {publishedSocket in
                        PublishedPathLabel(hostPath: publishedSocket.hostPath.absoluteString, containerPath: publishedSocket.containerPath.absoluteString)
                    }
                }
            }
            TableColumn("mounts", value: \.configuration.mounts.count) { container in
                if (container.status == .running) {
                    ForEach(container.configuration.mounts, id: \.destination) {mount in
                        if (mount.isVolume) {
                            let subSource = mount.source.dropLast(11)
                            PublishedPathLabel(hostPath: String(subSource), containerPath: mount.destination)
                        } else {
                            PublishedPathLabel(hostPath: mount.source, containerPath: mount.destination)
                        }
                    }
                }
            }
            TableColumn("") { container in
                ContainerListActionsView(viewModel: viewModel, id: container.id)
            }
            .width(105)
        } rows: {
            ForEach(sortedFilteredContainers, id: \.id) { container in
                TableRow(container)
            }
        }
        .tableStyle(.inset)
        .onChange(of: selection ?? "") { oldValue, newValue in
            if !newValue.isEmpty && newValue != oldValue {
                selection = nil
                viewModel.path.append(CraneRoute.detail(id: newValue))
            }
        }
    }
}
