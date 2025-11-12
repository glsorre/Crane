//
//  ContainerSidebarView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerClient
import ContainerNetworkService
import SwiftUI

struct ContainerSidebarView: View {
    @Bindable var viewModel: CraneViewModel
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        let networks = viewModel.networks
        List(selection: $viewModel.currentContainerId) {
            ForEach(networks!.sorted(), id: \.self) { network in
                Section(network.capitalized) {
                    let sortedContainers = viewModel.containersForNetwork[network]!.sorted {
                        $0.id < $1.id
                    }
                    ForEach(sortedContainers, id: \.id) { container in
                        HStack(alignment: .center) {
                            Text(container.id)
                            Spacer()
                            Label(container.status.getDescription(), systemImage: container.status.getIcon())
                                .foregroundColor(.secondary)
                                .font(.callout)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .listStyle(.automatic)
        .toolbar {
            ToolbarItem {
                Button("Settings", systemImage: "gear") {
                    openSettings()
                }
            }
            ToolbarSpacer()
            ToolbarItem {
                HStack {
                    Button("Network", systemImage: "cabinet") {
                        
                    }
                    Button("Container", systemImage: "plus") {
                        viewModel.showCreateSheet = true
                    }
                }
            }
        }
    }
}
