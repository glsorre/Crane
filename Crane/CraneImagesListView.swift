//
//  CraneImagesListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct CraneImagesListView: View {
    @State private var appViewModel = AppViewModel.shared
    @State private var imagesStore = ImagesStore.shared

    @State private var fetchingPopupIsVisible: Bool = false
    @State private var buildSheetIsVisible: Bool = false
    @State private var imageToFetch: String = ""

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
                    fetchingPopupIsVisible.toggle()
                }) {
                    SwiftUI.Image(systemName: "plus")
                }
                .buttonStyle(.glass)
                .popover(isPresented: $fetchingPopupIsVisible) {
                    Form {
                        TextField(String(localized: "fetchImageUrl"), text: $imageToFetch)
                        Button(action: {
                            Task {
                                do {
                                    fetchingPopupIsVisible.toggle()
                                    try await imagesStore.fetchImage(reference: imageToFetch)
                                } catch {
                                    AppViewModel.shared.showError(.imageFetchFailed(error.localizedDescription))
                                }
                            }
                        }) {
                            Text(String(localized: "fetchImage"))
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.regular)
                        .disabled(imageToFetch.isEmpty)
                    }
                    .formStyle(.grouped)
                    .frame(width: 400)
                    .padding(Spacing.sm)
                }
            }
        }
        .sheet(isPresented: $buildSheetIsVisible) {
            ImageBuildView(isPresented: $buildSheetIsVisible)
        }
        .searchable(text: $imagesStore.searchText, placement: .toolbar)
    }
}
