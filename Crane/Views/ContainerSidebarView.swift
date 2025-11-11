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
    @Bindable var viewModel: ViewModel
    
    
    var body: some View {
        if let containers = viewModel.containers, let networks = viewModel.networks {
            List(selection: $viewModel.currentContainerId) {
                ForEach(networks.sorted(by: { $0.network < $1.network }), id: \.network) { network in
                    Section(network.network.capitalized) {
                        let containersForNetwork = Array(containers.values).filter { $0.configuration.networks.contains { $0.network == network.network } }
                        ForEach(containersForNetwork, id: \.id) { container in
                            let iconName = container.status.getIcon()
                            HStack {
                                Text(container.id)
                                Spacer()
                                Image(
                                    systemName: iconName
                                )
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        } else {
            EmptyView()
        }
    }
}

