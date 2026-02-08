//
//  CraneVolumesListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 08/02/26.
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct CraneVolumesListView: View {
    @State private var appViewModel = AppViewModel.shared
    @State private var volumesStore = VolumesStore.shared

    @State private var creatingPopupIsVisible: Bool = false
    @State private var volumeToCreate: String = ""

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
                    creatingPopupIsVisible.toggle()
                }) {
                    SwiftUI.Image(systemName: "plus")
                }
                .buttonStyle(.glass)
                .popover(isPresented: $creatingPopupIsVisible) {
                    Form {
                        TextField(String(localized: "volumeToCreateName"), text: $volumeToCreate)
                        Button(action: {
                            Task {
                                do {
                                    creatingPopupIsVisible.toggle()
                                    try await volumesStore.createVolume(name: volumeToCreate)
                                } catch {
                                    AppViewModel.shared.showError(.volumeCreateFailed(error.localizedDescription))
                                }
                            }
                        }) {
                            Text(String(localized: "volumeToCreate"))
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.regular)
                        .disabled(volumeToCreate.isEmpty)
                    }
                    .formStyle(.grouped)
                    .frame(width: 400)
                    .padding(Spacing.sm)
                }
            }
        }
        .searchable(text: $volumesStore.searchText, placement: .toolbar)
    }
}
