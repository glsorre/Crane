//
//  CraneView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 06/11/25.
//

import ContainerClient
import ContainerNetworkService
import Containerization
import ContainerizationOS
import Combine
import Observation
import SwiftUI



struct CraneView: View {
    @State private var viewModel = ViewModel()
    
    var body: some View {
        NavigationSplitView {
            ContainerSidebarView(viewModel: viewModel)
        } detail: {
            if let currentId = viewModel.currentContainerId,
               let currentContainer = viewModel.containers?[currentId] {
                ContainerDetailsView(viewModel: $viewModel, container: currentContainer)
            } else {
                EmptyView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showCreateSheet = true
                } label: {
                    Label("New Container", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(isPresented: Binding(get: { viewModel.showCreateSheet }, set: { viewModel.showCreateSheet = $0 })) {
            ContainerCreationView(viewModel: $viewModel)
        }
        .task {
            await viewModel.initState()
            Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    await viewModel.listContainers()
                }
            }
        }
        .onChange(of: viewModel.currentContainerId) { oldValue, newValue in
            viewModel.selectedLogHandleIndex = 0
        }
    }
}

#Preview {
    CraneView()
}
