//
//  CraneVolumesListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 08/02/26.
//

import SwiftUI

struct CraneVolumesListView: View {
    @Environment(\.craneStores) private var stores
    private var volumesStore: VolumesStore { stores.volumes }

    @State private var createSheetIsVisible = false

    private var listItems: [CraneVolume] {
        volumesStore.sortedFilteredVolumes
    }

    var body: some View {
        ZStack {
            List(listItems) { volume in
                VolumeRowView(volume: volume)
            }
            .listStyle(.inset)
            .contentMargins(.top, Spacing.lg, for: .scrollContent)

            if listItems.isEmpty {
                MainListEmptyState(
                    searchText: volumesStore.searchText,
                    emptyTitle: "listEmptyVolumesTitle",
                    emptyDescription: "listEmptyVolumesDescription",
                    systemImage: "externaldrive"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    Task {
                        await volumesStore.pruneVolumes()
                    }
                }) {
                    SwiftUI.Image(systemName: "xmark.bin")
                }
                .buttonStyle(.glass)
                .disabled(!volumesStore.hasUnusedVolumes)
                .help(String(localized: "removeUnusedVolumes"))
                .accessibilityLabel(String(localized: "removeUnusedVolumes"))
            }
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    createSheetIsVisible = true
                }) {
                    SwiftUI.Image(systemName: "plus")
                }
                .buttonStyle(.glassProminent)
                .help(String(localized: "toolbarHelpAddVolume"))
                .accessibilityLabel(String(localized: "toolbarHelpAddVolume"))
            }
        }
        .sheet(isPresented: $createSheetIsVisible) {
            VolumeCreateView(isPresented: $createSheetIsVisible)
        }
    }
}
