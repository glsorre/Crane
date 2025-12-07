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

private let logger = Logger(subsystem: "com.example.Crane", category: "Launch")

struct CraneView: View {
    @State private var appViewModel = AppViewModel.shared
    @State private var containersStore = ContainersStore.shared
    
    var body: some View {
        NavigationStack(path: $appViewModel.path) {
            TabView {
                CraneContainersListView()
                    .tag(1)
                    .tabItem {
                        Text("containers")
                    }
                CraneNetworksListView()
                    .tag(2)
                    .tabItem {
                        Text("networks")
                    }
                CraneImagesListView()
                    .tag(3)
                    .tabItem {
                        Text("images")
                    }
            }
            .searchable(text: $containersStore.searchText, placement: .toolbar)
            .tabViewStyle(.automatic)
            .navigationDestination(for: CraneRoute.self) { route in
                switch route {
                case .detail(let container):
                    CraneDetailsView(container: container)
                case .list:
                    CraneContainersListView()
                }
            }
            .navigationTransition(.automatic)
        }
        .alert(isPresented: $appViewModel.errorShow) {
            var button = Alert.Button.default(Text("refresh")) {
                Task {
                    appViewModel.navigateTo(to: .list)
                    try await containersStore.reset()
                }
            }
            if appViewModel.error?.fatal == true {
                button = Alert.Button.destructive(Text("quit")) {
                    Task {
                        exit(1)
                    }
                }
            }
            return Alert(
                title: Text(String(localized: "craneError")),
                message: Text(appViewModel.error?.localizedDescription ?? String(localized: "unknownError")),
                dismissButton: button
            )
        }
        .onAppear {
            Task {
                let isRegistered = isServiceLoaded(label: "com.apple.container.apiserver", domain: "gui/\(getuid())")
                if !isRegistered {
                    appViewModel.showError(CraneError.notRegistered)
                    return
                    }
                
                do {
                    let _ = try await ClientHealthCheck.ping(timeout: .seconds(10))
                } catch {
                    appViewModel.showError(CraneError.notRunning)
                    return
                }
            }
        }
    }
}
