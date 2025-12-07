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
    @State private var appViewModel = AppViewModel.shared
    @State private var containersStore = ContainersStore.shared
    @State private var sortOrder = [KeyPathComparator(\Container.id, order: .forward)]
    @State private var selection: Container.ID?
    
    var body: some View {
        buildTable(containers: containersStore.sortedFilteredContainers)
            .tableStyle(.inset)
            .onChange(of: selection) { _, newValue in
                if let id = newValue {
                    selection = nil
                    let container = containersStore.containers.first(where: { $0.id == id })!
                    appViewModel.navigateTo(to: .detail(container: container))
                }
            }
    }
    
    private func buildTable(containers: [Container]) -> some View {
        return Table(of: Container.self, selection: $selection, sortOrder: $sortOrder) {
            // Active columns (start simple to avoid type-checking issues)
            TableColumn("name", value: \.id) { container in
                Text(container.id)
                    .padding(.vertical, 5)
            }
            TableColumn("status", value: \.container.status.rawValue) { container in
                SwiftUI.Image(systemName: container.container.status.getIcon())
                    .padding(.vertical, 5)
            }.width(60)
            TableColumn("cpus", value: \.container.configuration.resources.cpus) { container in
                Text(String(container.container.configuration.resources.cpus))
                    .padding(.vertical, 5)
            }.width(80)
            
            TableColumn("memory", value: \.container.configuration.resources.memoryInBytes) { container in
                let memoryInGiB = container.container.configuration.resources.memoryInBytes / 1024 / 1024 / 1024
                Text("\(memoryInGiB) GiB")
                    .padding(.vertical, 5)
            }.width(80)
            TableColumn("networks", value: \.container.networks.count) { container in
                ForEach(container.container.networks, id: \.network) {network in
                    Text(network.network)
                }
            }
            TableColumn("ips", value: \.container.networks.count) { container in
                ForEach(container.container.networks, id: \.network) {network in
                    Text(network.address)
                        .monospaced()
                }
            }
            TableColumn("ports", value: \.container.configuration.publishedPorts.count) { container in
                if (container.container.status == .running) {
                    ForEach(container.container.configuration.publishedPorts, id: \.containerPort) {publishedPort in
                        PublishedPortLabel(hostPort: Int(publishedPort.hostPort), containerPort: Int(publishedPort.containerPort))
                    }
                }
            }
            TableColumn("sockets", value: \.container.configuration.publishedSockets.count) { container in
                if (container.container.status == .running) {
                    ForEach(container.container.configuration.publishedSockets, id: \.containerPath) {publishedSocket in
                        PublishedPathLabel(hostPath: publishedSocket.hostPath.absoluteString, containerPath: publishedSocket.containerPath.absoluteString)
                    }
                }
            }
            TableColumn("mounts", value: \.container.configuration.mounts.count) { container in
                if (container.container.status == .running) {
                    ForEach(container.container.configuration.mounts, id: \.destination) {mount in
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
                ContainerListActionsView(containersStore: containersStore, id: container.id)
            }
            .width(105)
        } rows: {
            ForEach(containers, id: \.id) { container in
                TableRow(container)
            }
        }
    }
}
