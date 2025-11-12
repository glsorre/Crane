//
//  CraneView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 06/11/25.
//

import ContainerClient
import ContainerNetworkService
import ContainerPlugin
import Containerization
import ContainerizationOS
import Combine
import Observation
import SwiftUI

struct CraneView: View {
    @State private var viewModel = CraneViewModel()
    
    var body: some View {
        NavigationSplitView {
            if !viewModel.containers!.isEmpty, !viewModel.networks!.isEmpty {
                ContainerSidebarView(viewModel: viewModel)
            } else {
                EmptyView()
            }
        } detail: {
            if viewModel.currentContainerId != nil {
                ContainerDetailsView(viewModel: $viewModel)
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: Binding(get: { viewModel.showCreateSheet }, set: { viewModel.showCreateSheet = $0 })) {
            ContainerCreationView(viewModel: $viewModel)
        }
        .toolbar {
            if viewModel.currentContainerId != nil {
                ToolbarItem(placement: .primaryAction) {
                    Text(viewModel.currentContainerId ?? "")
                        .font(.title.bold())
                        .padding()
                }
            }
        }
        .onAppear {
            Task {
                do {
                    let _ = try await ClientHealthCheck.ping(timeout: .seconds(10))
                } catch {
                    let alert = NSAlert()
                    alert.messageText = "No Apple container service is running"
                    alert.informativeText = "Please run the Apple container service to use this tool."
                    alert.runModal()
                    exit(1)
                }
                await viewModel.initState()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(UserDefaults().integer(forKey: "refreshInterval")))
                    await viewModel.listContainers()
                }
            }
        }
        .onChange(of: viewModel.currentContainerId) { oldValue, newValue in
            viewModel.currentLogHandle = 0
        }
    }
}

#Preview {
    CraneView()
}
