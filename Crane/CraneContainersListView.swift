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
    @State private var appViewModel = AppViewModel.shared
    @State private var containersStore = ContainersStore.shared
    @State private var selection: Container.ID?
    @State private var runSheetIsVisible: Bool = false

    private var listItems: [Container] {
        containersStore.sortedFilteredContainers
    }

    var body: some View {
        ZStack {
            List(listItems, selection: $selection) { container in
                ContainerRowView(container: container)
                    .tag(container.id)
            }
            .listStyle(.inset)

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
        .onChange(of: selection) { _, newValue in
            guard let id = newValue else { return }
            selection = nil
            guard let container = containersStore.containers.first(where: { $0.id == id }) else { return }
            appViewModel.navigateTo(to: .detail(container: container))
        }
        .searchable(text: $containersStore.searchText, placement: .toolbar)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    runSheetIsVisible = true
                } label: {
                    SwiftUI.Image(systemName: "plus")
                }
                .buttonStyle(.glass)
                .help(String(localized: "toolbarHelpAddContainer"))
                .accessibilityLabel(String(localized: "toolbarHelpAddContainer"))
            }
        }
        .sheet(isPresented: $runSheetIsVisible) {
            ContainerRunView(isPresented: $runSheetIsVisible)
        }
    }
}
