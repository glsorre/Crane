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
    @State private var imagesStore = ImagesStore.shared
    @State private var networksStore = NetworksStore.shared
    @State private var volumesStore = VolumesStore.shared
    @State private var isStartingService = false

    private var selectedTabBinding: Binding<CraneTab?> {
        Binding(
            get: { appViewModel.selectedTab },
            set: { newValue in
                guard let newValue else { return }
                appViewModel.selectedTab = newValue
            }
        )
    }

    private var activeSearchText: Binding<String> {
        switch appViewModel.selectedTab {
        case .containers:
            return $containersStore.searchText
        case .images:
            return $imagesStore.searchText
        case .networks:
            return $networksStore.searchText
        case .volumes:
            return $volumesStore.searchText
        }
    }

    private var shouldShowToolbarSearch: Bool {
        !(appViewModel.selectedTab == .containers && appViewModel.selectedContainerID != nil)
    }

    private var splitViewContent: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(selection: selectedTabBinding) {
                Label("containers", systemImage: "shippingbox.fill")
                    .tag(CraneTab.containers)
                Label("images", systemImage: "photo.fill")
                    .tag(CraneTab.images)
                Label("networks", systemImage: "network")
                    .tag(CraneTab.networks)
                Label("volumes", systemImage: "externaldrive.fill")
                    .tag(CraneTab.volumes)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        } detail: {
            Group {
                switch appViewModel.selectedTab {
                case .containers:
                    CraneContainersListView()
                case .images:
                    CraneImagesListView()
                case .networks:
                    CraneNetworksListView()
                case .volumes:
                    CraneVolumesListView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
    }

    var body: some View {
        Group {
            if shouldShowToolbarSearch {
                splitViewContent
                    .searchable(text: activeSearchText, placement: .toolbar)
            } else {
                splitViewContent
            }
        }
        .alert(String(localized: "craneError"), isPresented: $appViewModel.errorShow) {
            if appViewModel.error?.fatal == true {
                Button("quit", role: .destructive) { exit(1) }
            } else {
                Button("refresh") {
                    Task {
                        appViewModel.showContainersList()
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
                guard !AppSettings.isRunningTests else { return }
                let serviceLabel = "com.apple.container.apiserver"
                let domain = "gui/\(getuid())"
                var isRegistered = isServiceLoaded(label: serviceLabel, domain: domain)

                if !isRegistered && AppSettings.launchContainerizationService {
                    isStartingService = true
                    logger.info("Starting container service…")
                    let started = await startContainerService()
                    if !started {
                        logger.warning("startContainerService() failed")
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
