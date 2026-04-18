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

    var body: some View {
        List(imagesStore.sortedFilteredImages) { image in
            ImageRowView(image: image)
        }
        .listStyle(.inset)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    buildSheetIsVisible.toggle()
                }) {
                    SwiftUI.Image(systemName: "hammer.fill")
                }
                .buttonStyle(.glass)
            }
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    fetchSheetIsVisible = true
                }) {
                    SwiftUI.Image(systemName: "plus")
                }
                .buttonStyle(.glass)
            }
        }
        .sheet(isPresented: $fetchSheetIsVisible) {
            ImageFetchView(isPresented: $fetchSheetIsVisible)
        }
        .sheet(isPresented: $buildSheetIsVisible) {
            ImageBuildView(isPresented: $buildSheetIsVisible)
        }
        .searchable(text: $imagesStore.searchText, placement: .toolbar)
    }
}
