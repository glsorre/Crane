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

    var body: some View {
        List(containersStore.sortedFilteredContainers, selection: $selection) { container in
            ContainerRowView(container: container)
                .tag(container.id)
        }
        .listStyle(.inset)
        .onChange(of: selection) { _, newValue in
            if let id = newValue {
                selection = nil
                let container = containersStore.containers.first(where: { $0.id == id })!
                appViewModel.navigateTo(to: .detail(container: container))
            }
        }
        .searchable(text: $containersStore.searchText, placement: .toolbar)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    runSheetIsVisible = true
                } label: {
                    SwiftUI.Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $runSheetIsVisible) {
            ContainerRunView(isPresented: $runSheetIsVisible)
        }
    }
}
