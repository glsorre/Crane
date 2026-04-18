//
//  CraneNetworksListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import SwiftUI

struct CraneNetworksListView: View {
    @State private var networksStore = NetworksStore.shared

    @State private var createSheetIsVisible = false

    private var listItems: [Network] {
        networksStore.sortedFilteredNetworks
    }

    var body: some View {
        ZStack {
            List(listItems) { network in
                NetworkRowView(network: network)
            }
            .listStyle(.inset)

            if listItems.isEmpty {
                MainListEmptyState(
                    searchText: networksStore.searchText,
                    emptyTitle: "listEmptyNetworksTitle",
                    emptyDescription: "listEmptyNetworksDescription",
                    systemImage: "network"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        }
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
                .help(String(localized: "removeEmptyNetworks"))
                .accessibilityLabel(String(localized: "removeEmptyNetworks"))
            }
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    createSheetIsVisible = true
                }) {
                    SwiftUI.Image(systemName: "plus")
                }
                .buttonStyle(.glass)
                .help(String(localized: "toolbarHelpAddNetwork"))
                .accessibilityLabel(String(localized: "toolbarHelpAddNetwork"))
            }
        }
        .sheet(isPresented: $createSheetIsVisible) {
            NetworkCreateView(isPresented: $createSheetIsVisible)
        }
        .searchable(text: $networksStore.searchText, placement: .toolbar)
    }
}
