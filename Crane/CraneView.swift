//
//  CraneView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 06/11/25.
//

import ContainerAPIClient
import ContainerizationError
import ContainerResource
import ContainerPlugin
import Containerization
import ContainerizationOS
import Observation
import SwiftUI
import os.log

private let logger = Logger(subsystem: "me.rightright.RightCrane", category: "Launch")

struct CraneView: View {
    @State private var appViewModel = AppViewModel.shared
    @State private var containersStore = ContainersStore.shared
    
    var body: some View {
        NavigationStack(path: $appViewModel.path) {
            TabView {
                Tab("containers", systemImage: "shippingbox.fill") {
                    CraneContainersListView()
                }
                Tab("images", systemImage: "photo.fill") {
                    CraneImagesListView()
                }
                Tab("networks", systemImage: "network") {
                    CraneNetworksListView()
                }
            }
            .tabViewStyle(.sidebarAdaptable)
            .navigationDestination(for: CraneRoute.self) { route in
                switch route {
                case .detail(let container):
                    CraneDetailsView(container: container)
                case .list:
                    CraneContainersListView()
                }
            }
        }
        .alert(String(localized: "craneError"), isPresented: $appViewModel.errorShow) {
            if appViewModel.error?.fatal == true {
                Button("quit", role: .destructive) { exit(1) }
            } else {
                Button("refresh") {
                    Task {
                        appViewModel.navigateTo(to: .list)
                        try await ContainersStore.shared.reset()
                        try await ImagesStore.shared.reset()
                        try await NetworksStore.shared.reset()
                    }
                }
            }
        } message: {
            Text(appViewModel.error?.localizedDescription ?? String(localized: "unknownError"))
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
