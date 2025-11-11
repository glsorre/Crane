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
    
    var body: some View {
        let networks = viewModel.networks
        List(selection: $viewModel.currentContainerId) {
            ForEach(networks!.sorted(), id: \.self) { network in
                Section(network.capitalized) {
                    ForEach(viewModel.containersForNetwork[network]!, id: \.id) { container in
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
    }
}
