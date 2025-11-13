//
//  CraneView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 06/11/25.
//

import ContainerClient
import ContainerizationError
import ContainerNetworkService
import ContainerPlugin
import Containerization
import ContainerizationOS
import Combine
import Observation
import SwiftUI

struct CraneView: View {
    @State private var viewModel = CraneViewModel()
    
    enum CraneError: LocalizedError {
        case notRegistered(String)
        case notRunning(String)
        
        var errorDescription: String? {
            switch self {
            case .notRegistered(let message):
                return message
            case .notRunning(let message):
                return message
            }
        }
    }
    
    func kill() {
        exit(1)
    }
    
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
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("Crane fatal error"),
                message: Text(viewModel.error!.localizedDescription),
                dismissButton: .default(
                    Text("Exit"),
                    action: kill
                )
            )
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
                    let isRegistered = isServiceLoaded(label: "com.apple.container.apiserver", domain: "gui/\(getuid())")
                    
                    if !isRegistered {
                        throw CraneError.notRegistered("Apple containers service is not registered")
                    }
                } catch {
                    viewModel.error = error
                    viewModel.showError = true
                    return
                }
                 
                do {
                    let _ = try await ClientHealthCheck.ping(timeout: .seconds(10))
                } catch {
                    viewModel.error = CraneError.notRunning("Failed to ping the Apple containers service")
                    viewModel.showError = true
                    return
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
    
    // Define these action methods as needed (examples below)
    private func saveWorkoutData() {
        // Implement retry logic for saving or re-pinging the container service
        // e.g., await viewModel.retryConnection()
    }
    
    private func deleteWorkoutData() {
        // Implement deletion logic for clearing state or logs
        // e.g., viewModel.clearError()
    }
}

