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
                        Text("Containers")
                    }
                CraneNetworksListView(viewModel: viewModel)
                    .tag(3)
                    .tabItem {
                        Text("Networks")
                    }
//                CraneContainersListView(viewModel: viewModel)
//                    .tag(2)
//                    .tabItem {
//                        Text("Images")
//                    }
//                CraneContainersListView(viewModel: viewModel)
//                    .tag(4)
//                    .tabItem {
//                        Text("Volumes")
//                    }
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
                title: Text("Crane fatal error"),
                message: Text(viewModel.error!.localizedDescription),
                dismissButton: .default(
                    Text("Exit"),
                    action: kill
                )
            )
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
    }
}
