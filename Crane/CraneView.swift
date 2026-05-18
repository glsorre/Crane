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

enum LaunchPhase: Equatable {
    case idle
    case checking
    case startingService
    case waitingForRegistration
    case waitingForHealth
}

struct CraneView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.craneStores) private var stores
    private var appViewModel: AppViewModel { stores.app }
    private var containersStore: ContainersStore { stores.containers }
    private var imagesStore: ImagesStore { stores.images }
    private var networksStore: NetworksStore { stores.networks }
    private var volumesStore: VolumesStore { stores.volumes }
    @State private var launchPhase: LaunchPhase = .idle
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

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
            return Binding(get: { stores.containers.searchText }, set: { stores.containers.searchText = $0 })
        case .images:
            return Binding(get: { stores.images.searchText }, set: { stores.images.searchText = $0 })
        case .networks:
            return Binding(get: { stores.networks.searchText }, set: { stores.networks.searchText = $0 })
        case .volumes:
            return Binding(get: { stores.volumes.searchText }, set: { stores.volumes.searchText = $0 })
        }
    }

    private var shouldShowToolbarSearch: Bool {
        !(appViewModel.selectedTab == .containers && appViewModel.selectedContainerID != nil)
    }

    private var splitViewContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
            .safeAreaInset(edge: .bottom) {
                ConnectionStatusPill(tracker: stores.connectionHealth, stores: stores)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
            }
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

    private var launchPhaseLabel: String {
        switch launchPhase {
        case .idle, .checking:
            return String(localized: "launchPhaseChecking")
        case .startingService:
            return String(localized: "launchPhaseStartingService")
        case .waitingForRegistration:
            return String(localized: "launchPhaseWaitingForRegistration")
        case .waitingForHealth:
            return String(localized: "launchPhaseWaitingForHealth")
        }
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
        .alert(String(localized: "craneError"), isPresented: Binding(get: { appViewModel.errorShow }, set: { appViewModel.errorShow = $0 })) {
            if appViewModel.error?.fatal == true {
                Button("quit", role: .destructive) { exit(1) }
            } else {
                Button("refresh") {
                    Task {
                        appViewModel.showContainersList()
                        try await stores.resetAll()
                    }
                }
            }
        } message: {
            LaunchErrorMessage(error: appViewModel.error)
        }
        .overlay {
            if launchPhase != .idle {
                VStack(spacing: Spacing.sm) {
                    ProgressView()
                        .controlSize(.large)
                    Text(launchPhaseLabel)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
            }
        }
        .onAppear {
            Task { await runLaunchSequence() }
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            let visible = newPhase == .active
            PollingVisibility.setSceneActive(visible)
            if visible {
                // Only the active tab's store needs a kick — the others are paused.
                stores.activateTab(appViewModel.selectedTab.polledResource)
            }
        }
        .onChange(of: appViewModel.selectedTab, initial: true) { _, newTab in
            stores.activateTab(newTab.polledResource)
        }
    }

    @MainActor
    private func runLaunchSequence() async {
        guard !AppSettings.isRunningTests else { return }
        let serviceLabel = "com.apple.container.apiserver"
        let domain = "gui/\(getuid())"
        var diagnostic = LaunchDiagnostic()

        launchPhase = .checking
        var registrationState = launchctlState(label: serviceLabel, domain: domain)
        diagnostic.serviceRegistered = registrationState.loaded
        diagnostic.launchctlPrintOutput = registrationState.rawOutput
        diagnostic.cliPath = containerCLIExecutableURL()?.path

        if !registrationState.loaded && AppSettings.launchContainerizationService {
            launchPhase = .startingService
            Log.launch.info("Starting container service…")
            let result = await startContainerService()
            diagnostic.cliPath = result.cliPath ?? diagnostic.cliPath
            diagnostic.startAttemptStderr = result.stderr
            diagnostic.plistFound = result.plistFound
            Log.launch.info("startContainerService() returned success=\(result.success)")

            launchPhase = .waitingForRegistration
            for _ in 0..<30 {
                try? await Task.sleep(for: .milliseconds(500))
                registrationState = launchctlState(label: serviceLabel, domain: domain)
                if registrationState.loaded {
                    diagnostic.serviceRegistered = true
                    diagnostic.launchctlPrintOutput = registrationState.rawOutput
                    break
                }
            }
            diagnostic.serviceRegistered = registrationState.loaded
            diagnostic.launchctlPrintOutput = registrationState.rawOutput
        }

        if !diagnostic.serviceRegistered {
            launchPhase = .idle
            appViewModel.showError(.notRegistered(diagnostic: diagnostic))
            return
        }

        launchPhase = .waitingForHealth
        Log.launch.info("Service registered, waiting for API server…")
        var healthy = false
        var lastPingError: String?
        for _ in 0..<60 {
            do {
                _ = try await ClientHealthCheck.ping(timeout: .seconds(2))
                healthy = true
                break
            } catch {
                lastPingError = error.localizedDescription
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
        diagnostic.pingError = healthy ? nil : lastPingError

        launchPhase = .idle
        if !healthy {
            appViewModel.showError(.notRunning(diagnostic: diagnostic))
        }
    }
}

private struct LaunchErrorMessage: View {
    let error: CraneError?

    var body: some View {
        if let diagnostic = error?.diagnostic {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(error?.localizedDescription ?? String(localized: "unknownError"))
                Text(String(localized: "launchDiagnosticServiceRegistered \(diagnostic.serviceRegistered ? String(localized: "yes") : String(localized: "no"))"))
                Text(String(localized: "launchDiagnosticCliPath \(diagnostic.cliPath ?? String(localized: "notFound"))"))
                Text(String(localized: "launchDiagnosticPlistFound \(diagnostic.plistFound ? String(localized: "yes") : String(localized: "no"))"))
                if let stderr = diagnostic.startAttemptStderr, !stderr.isEmpty {
                    Text(stderr)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                if let pingError = diagnostic.pingError, !pingError.isEmpty {
                    Text(pingError)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        } else {
            Text(error?.localizedDescription ?? String(localized: "unknownError"))
        }
    }
}
