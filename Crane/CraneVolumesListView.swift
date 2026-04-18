//
//  CraneVolumesListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 08/02/26.
//

import SwiftUI

struct CraneVolumesListView: View {
    @State private var volumesStore = VolumesStore.shared

    @State private var createSheetIsVisible = false

    var body: some View {
        List(volumesStore.sortedFilteredVolumes) { volume in
            VolumeRowView(volume: volume)
        }
        .listStyle(.inset)
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
                .help("removeUnusedVolumes")
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
            VolumeCreateView(isPresented: $createSheetIsVisible)
        }
        .searchable(text: $volumesStore.searchText, placement: .toolbar)
    }
}
