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
    @State private var isStartingService = false

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
                Tab("volumes", systemImage: "externaldrive.fill") {
                    CraneVolumesListView()
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
                        try await VolumesStore.shared.reset()
                    }
                }
            }
        } message: {
            Text(appViewModel.error?.localizedDescription ?? String(localized: "unknownError"))
        }
        .overlay {
            if isStartingService {
                VStack(spacing: Spacing.sm) {
                    ProgressView()
                        .controlSize(.large)
                    Text("startingServices")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
            }
        }
        .onAppear {
            Task {
                let serviceLabel = "com.apple.container.apiserver"
                let domain = "gui/\(getuid())"
                var isRegistered = isServiceLoaded(label: serviceLabel, domain: domain)

                if !isRegistered && AppSettings.launchContainerizationService {
                    isStartingService = true
                    logger.info("Starting container service via launchctl bootstrap…")
                    let started = await startContainerService()
                    if !started {
                        logger.warning("startContainerService() failed — plist may be missing (run `container system start` once)")
                    }
                    logger.info("startContainerService() returned success=\(started)")
                    // Wait for the service to register (up to 15s)
                    for _ in 0..<30 {
                        try await Task.sleep(for: .milliseconds(500))
                        if isServiceLoaded(label: serviceLabel, domain: domain) {
                            isRegistered = true
                            break
                        }
                    }
                }

                if !isRegistered {
                    isStartingService = false
                    appViewModel.showError(CraneError.notRegistered)
                    return
                }

                // Wait for the API server to become responsive (up to 30s)
                if isStartingService {
                    logger.info("Service registered, waiting for API server…")
                }
                var healthy = false
                for _ in 0..<60 {
                    do {
                        let _ = try await ClientHealthCheck.ping(timeout: .seconds(2))
                        healthy = true
                        break
                    } catch {
                        try await Task.sleep(for: .milliseconds(500))
                    }
                }

                isStartingService = false
                if !healthy {
                    appViewModel.showError(CraneError.notRunning)
                }
            }
        }
    }
}
