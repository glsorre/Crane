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
import os.log

// Add a logger for debugging launch issues
private let logger = Logger(subsystem: "com.example.Crane", category: "Launch")

enum CraneRoute: Hashable {
    case detail(id: String)
    case list
}

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
        NavigationStack(path: $viewModel.path) {
            TabView {
                CraneContainersListView(viewModel: viewModel)
                    .tag(1)
                    .tabItem {
                        Text("containers")
                    }
                CraneNetworksListView(viewModel: viewModel)
                    .tag(2)
                    .tabItem {
                        Text("networks")
                    }
                CraneImagesListView(viewModel: viewModel)
                    .tag(3)
                    .tabItem {
                        Text("images")
                    }
                CraneVolumesListView(viewModel: viewModel)
                    .tag(4)
                    .tabItem {
                        Text("volumes")
                    }
            }
            .searchable(text: $viewModel.searchText, placement: .toolbar)
            .tabViewStyle(.automatic)
            .navigationDestination(for: CraneRoute.self) { route in
                switch route {
                case .detail(let id):
                    ContainerDetailsView(viewModel: viewModel, id: id)
                case .list:
                    CraneContainersListView(viewModel: viewModel)
                }
            }
            .navigationTransition(.automatic)
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text("craneFatalError"),
                message: Text(viewModel.error!.localizedDescription),
                dismissButton: .default(
                    Text("exit"),
                    action: kill
                )
            )
        }
        .onAppear {
            Task {
                // Log start of checks
                logger.info("Starting Crane launch checks...")
                
                do {
                    let isRegistered = isServiceLoaded(label: "com.apple.container.apiserver", domain: "gui/\(getuid())")
                    logger.info("Service registration check: \(isRegistered)")
                    
                    if !isRegistered {
                        logger.error("Service not registered")
                        throw CraneError.notRegistered(String(localized: "infoNotRegistered"))
                    }
                } catch {
                    logger.error("Registration check failed: \(error.localizedDescription)")
                    viewModel.error = error
                    viewModel.showError = true
                    return
                }
                 
                do {
                    logger.info("Performing health check ping...")
                    let _ = try await ClientHealthCheck.ping(timeout: .seconds(10))
                    logger.info("Health check successful")
                } catch {
                    logger.error("Health check failed: \(error.localizedDescription)")
                    viewModel.error = CraneError.notRunning(String(localized: "infoNotRunning"))
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
    }
}

