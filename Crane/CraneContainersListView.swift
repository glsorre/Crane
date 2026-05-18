//
//  CraneContainersListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct CraneContainersListView: View {
    @Environment(\.craneStores) private var stores
    private var appViewModel: AppViewModel { stores.app }
    private var containersStore: ContainersStore { stores.containers }
    @State private var runSheetIsVisible: Bool = false
    @State private var navigationPath: [Container.ID] = []

    private var listItems: [Container] {
        containersStore.sortedFilteredContainers
    }

    private func container(for id: Container.ID) -> Container? {
        containersStore.containers.first(where: { $0.id == id })
    }

    private func syncNavigationFromSelection() {
        guard let selectedID = appViewModel.selectedContainerID else {
            if !navigationPath.isEmpty {
                navigationPath.removeAll()
            }
            return
        }

        guard container(for: selectedID) != nil else {
            if !navigationPath.isEmpty {
                navigationPath.removeAll()
            }
            return
        }

        if navigationPath.last != selectedID {
            navigationPath = [selectedID]
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                List(listItems) { container in
                    NavigationLink(value: container.id) {
                        ContainerRowView(container: container)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
                .contentMargins(.top, Spacing.lg, for: .scrollContent)

                if listItems.isEmpty {
                    MainListEmptyState(
                        searchText: containersStore.searchText,
                        emptyTitle: "listEmptyContainersTitle",
                        emptyDescription: "listEmptyContainersDescription",
                        systemImage: "shippingbox"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                }
            }
            .navigationDestination(for: Container.ID.self) { containerID in
                if let container = container(for: containerID) {
                    CraneDetailsView(container: container, stores: stores)
                } else {
                    ContentUnavailableView(
                        "containerNotFound",
                        systemImage: "shippingbox",
                        description: Text("This container is no longer available.")
                    )
                }
            }
        }
        .onAppear {
            syncNavigationFromSelection()
        }
        .onChange(of: appViewModel.containerDetailNavigationRequest) {
            syncNavigationFromSelection()
        }
        .onChange(of: appViewModel.selectedContainerID) {
            syncNavigationFromSelection()
        }
        .onChange(of: navigationPath) { _, newPath in
            let currentID = newPath.last
            if appViewModel.selectedContainerID != currentID {
                appViewModel.selectedContainerID = currentID
            }
        }
        .onChange(of: containersStore.sortedFilteredContainers.map(\.id)) {
            syncNavigationFromSelection()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    Task { await containersStore.pruneExitedContainers() }
                } label: {
                    SwiftUI.Image(systemName: "xmark.bin")
                }
                .buttonStyle(.glass)
                .disabled(!containersStore.hasExitedContainers)
                .help(String(localized: "pruneExitedContainers"))
                .accessibilityLabel(String(localized: "pruneExitedContainers"))
            }
            ToolbarItem(placement: .navigation) {
                Button {
                    runSheetIsVisible = true
                } label: {
                    SwiftUI.Image(systemName: "plus")
                }
                .buttonStyle(.glassProminent)
                .help(String(localized: "toolbarHelpAddContainer"))
                .accessibilityLabel(String(localized: "toolbarHelpAddContainer"))
            }
        }
        .sheet(isPresented: $runSheetIsVisible) {
            ContainerRunView(isPresented: $runSheetIsVisible, stores: stores)
        }
    }
}
