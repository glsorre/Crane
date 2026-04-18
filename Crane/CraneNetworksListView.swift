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
                    createSheetIsVisible = true
                }) {
                    SwiftUI.Image(systemName: "plus")
                }
                .buttonStyle(.glass)
            }
        }
        .sheet(isPresented: $createSheetIsVisible) {
            NetworkCreateView(isPresented: $createSheetIsVisible)
        }
        .searchable(text: $networksStore.searchText, placement: .toolbar)
    }
}
