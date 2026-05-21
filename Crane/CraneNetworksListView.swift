//
//  CraneNetworksListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import SwiftUI

struct CraneNetworksListView: View {
    @Environment(\.craneStores) private var stores
    private var networksStore: NetworksStore { stores.networks }

    @State private var createSheetIsVisible = false

    private var listItems: [Network] {
        networksStore.sortedFilteredNetworks
    }

    var body: some View {
        ZStack {
            List(listItems) { network in
                NetworkRowView(network: network)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, Spacing.xxs)
            }
            .listStyle(.inset)
            .safeAreaPadding(.top, Spacing.lg)

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
                Button(
                    action: {
                        Task { await networksStore.pruneNetworks() }
                    },
                    label: { SwiftUI.Image(systemName: "xmark.bin") }
                )
                .buttonStyle(.glass)
                .disabled(!networksStore.hasEmptyNetworks)
                .help(String(localized: "removeEmptyNetworks"))
                .accessibilityLabel(String(localized: "removeEmptyNetworks"))
            }
            ToolbarItem(placement: .navigation) {
                Button(
                    action: { createSheetIsVisible = true },
                    label: { SwiftUI.Image(systemName: "plus") }
                )
                .buttonStyle(.glassProminent)
                .help(String(localized: "toolbarHelpAddNetwork"))
                .accessibilityLabel(String(localized: "toolbarHelpAddNetwork"))
            }
        }
        .sheet(isPresented: $createSheetIsVisible) {
            NetworkCreateView(isPresented: $createSheetIsVisible)
        }
    }
}
