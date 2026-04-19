//
//  CraneImagesListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import SwiftUI

struct CraneImagesListView: View {
    @State private var imagesStore = ImagesStore.shared

    @State private var fetchSheetIsVisible = false
    @State private var buildSheetIsVisible = false

    private var listItems: [Image] {
        imagesStore.sortedFilteredImages
    }

    var body: some View {
        ZStack {
            List {
                ForEach(listItems, id: \.objectIdentity) { image in
                    ImageRowView(image: image)
                }
            }
            .listStyle(.inset)

            if listItems.isEmpty {
                MainListEmptyState(
                    searchText: imagesStore.searchText,
                    emptyTitle: "listEmptyImagesTitle",
                    emptyDescription: "listEmptyImagesDescription",
                    systemImage: "photo"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    buildSheetIsVisible.toggle()
                }) {
                    SwiftUI.Image(systemName: "hammer.fill")
                }
                .buttonStyle(.glass)
                .help(String(localized: "toolbarHelpBuildImage"))
                .accessibilityLabel(String(localized: "toolbarHelpBuildImage"))
            }
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    fetchSheetIsVisible = true
                }) {
                    SwiftUI.Image(systemName: "plus")
                }
                .buttonStyle(.glassProminent)
                .help(String(localized: "toolbarHelpFetchImage"))
                .accessibilityLabel(String(localized: "toolbarHelpFetchImage"))
            }
        }
        .sheet(isPresented: $fetchSheetIsVisible) {
            ImageFetchView(isPresented: $fetchSheetIsVisible)
        }
        .sheet(isPresented: $buildSheetIsVisible) {
            ImageBuildView(isPresented: $buildSheetIsVisible)
        }
    }
}
