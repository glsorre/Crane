//
//  CraneNetworksListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct CraneNetworksListView: View {
    @State private var appViewModel = AppViewModel.shared
    @State private var networksStore = NetworksStore.shared

    @State private var creatingPopupIsVisible: Bool = false
    @State private var networkToCreate: String = ""

    var body: some View {
        List(networksStore.sortedFilteredNetworks) { network in
            NetworkRowView(network: network)
        }
        .listStyle(.inset)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    Task {
                        await networksStore.pruneNetworks()
                    }
                }) {
                    SwiftUI.Image(systemName: "xmark.bin")
                }
                .buttonStyle(.glass)
                .disabled(!networksStore.hasEmptyNetworks)
                .help("removeEmptyNetworks")
            }
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    creatingPopupIsVisible.toggle()
                }) {
                    SwiftUI.Image(systemName: "plus")
                }
                .buttonStyle(.glass)
                .popover(isPresented: $creatingPopupIsVisible) {
                    Form {
                        TextField(String(localized: "networkToCreateName"), text: $networkToCreate)
                        Button(action: {
                            Task {
                                do {
                                    creatingPopupIsVisible.toggle()
                                    try await networksStore.createNetwork(id: networkToCreate)
                                } catch {
                                    AppViewModel.shared.showError(.networkCreateFailed(error.localizedDescription))
                                }
                            }
                        }) {
                            Text(String(localized: "networkToCreate"))
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.regular)
                        .disabled(networkToCreate.isEmpty)
                    }
                    .formStyle(.grouped)
                    .frame(width: 400)
                    .padding(Spacing.sm)
                }
            }
        }
        .searchable(text: $networksStore.searchText, placement: .toolbar)
    }
}
