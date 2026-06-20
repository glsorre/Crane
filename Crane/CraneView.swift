//
//  CraneView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 06/11/25.
//

import ContainerAPIClient
import ContainerPlugin
import ContainerResource
import Containerization
import ContainerizationError
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

/// Maximum time the launch health-ping loop blocks the UI on a non-responding apiserver.
/// Total wait ≈ `healthPingAttempts × (healthPingTimeout + healthPingGap)`.
private let healthPingAttempts = 10
private let healthPingTimeout: Duration = .seconds(1)
private let healthPingGap: Duration = .milliseconds(500)

/// Hard outer timeout wrapper. `ClientHealthCheck.ping(timeout:)` only enforces a
/// deadline on connection setup, not on the XPC reply — if the apiserver process is
/// registered with launchd but never replies (hung kernel, broken handler), the inner
/// timeout never fires and the call blocks indefinitely. Racing the call against a
/// sleep here guarantees the health loop always makes progress.
private enum HardTimeoutError: LocalizedError {
    case timeout
    var errorDescription: String? { String(localized: "pingHardTimeout") }
}

private func withHardTimeout<T: Sendable>(
    _ timeout: Duration,
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: timeout)
            throw HardTimeoutError.timeout
        }
        do {
            guard let result = try await group.next() else {
                throw CancellationError()
            }
            group.cancelAll()
            return result
        } catch {
            group.cancelAll()
            throw error
        }
    }
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
    @State private var onboardingViewModel: OnboardingViewModel = OnboardingViewModel()
    @State private var showOnboarding: Bool = !AppSettings.hasCompletedOnboarding
    @State private var healthAttempt: Int = 0
    @State private var lastPingError: String?
    @State private var launchTask: Task<Void, Never>?
    @State private var launchDiagnostic: LaunchDiagnostic = .empty

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
        case .settings:
            return Binding(get: { "" }, set: { _ in })
        }
    }

    private var shouldShowToolbarSearch: Bool {
        !(appViewModel.selectedTab == .containers && appViewModel.selectedContainerID != nil)
    }

    /// Sidebar-row styled button for the Settings tab, rendered inside the
    /// sidebar's bottom `safeAreaInset` so it sits flush against the
    /// connection status pill and shares the same horizontal padding.
    @ViewBuilder
    private var sidebarSettingsRow: some View {
        let isSelected = appViewModel.selectedTab == .settings
        Button {
            appViewModel.selectedTab = .settings
        } label: {
            Label("settings", systemImage: "gearshape")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.25))
                    .padding(.horizontal, Spacing.xxs)
            }
        }
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var splitViewContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: selectedTabBinding) {
                Section {
                    Label("containers", systemImage: "shippingbox.fill")
                        .tag(CraneTab.containers)
                    Label("images", systemImage: "photo.fill")
                        .tag(CraneTab.images)
                    Label("networks", systemImage: "network")
                        .tag(CraneTab.networks)
                    Label("volumes", systemImage: "externaldrive.fill")
                        .tag(CraneTab.volumes)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    sidebarSettingsRow
                    ConnectionStatusPill(tracker: stores.connectionHealth, stores: stores)
                }
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
                case .settings:
                    CraneSettingsView()
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
        .alert(String(localized: "craneError"), isPresented: Binding(get: { appViewModel.errorShow }, set: { appViewModel.errorShow = $0 }))
        {
            if appViewModel.error?.fatal == true {
                Button("retry") {
                    launchTask = Task { await runLaunchSequence() }
                }
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
                    if launchPhase == .waitingForHealth {
                        Text(String(format: String(localized: "launchPhaseAttemptCount"), healthAttempt, healthPingAttempts))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        if let err = lastPingError, !err.isEmpty {
                            Text(err)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .lineLimit(3)
                                .multilineTextAlignment(.center)
                                .textSelection(.enabled)
                                .padding(.horizontal, Spacing.lg)
                        }
                        Button(String(localized: "cancel"), role: .cancel) {
                            launchTask?.cancel()
                            launchPhase = .idle
                            appViewModel.showError(.notRunning(diagnostic: launchDiagnostic))
                        }
                        .padding(.top, Spacing.xs)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
            }
        }
        .onAppear {
            if !showOnboarding {
                launchTask = Task { await runLaunchSequence() }
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(viewModel: onboardingViewModel) {
                showOnboarding = false
                launchTask = Task { await runLaunchSequence() }
            }
            .interactiveDismissDisabled(true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .craneRunOnboardingAgain)) { _ in
            onboardingViewModel = OnboardingViewModel()
            showOnboarding = true
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
        launchDiagnostic = diagnostic
        healthAttempt = 0
        lastPingError = nil
        Log.launch.info("Service registered, waiting for API server…")
        var healthy = false
        for _ in 0..<healthPingAttempts {
            if Task.isCancelled { break }
            do {
                _ = try await withHardTimeout(healthPingTimeout) {
                    try await ClientHealthCheck.ping(timeout: healthPingTimeout)
                }
                healthy = true
                healthAttempt = 0
                lastPingError = nil
                break
            } catch {
                healthAttempt += 1
                lastPingError = error.localizedDescription
                try? await Task.sleep(for: healthPingGap)
            }
        }
        diagnostic.pingError = healthy ? nil : lastPingError
        launchDiagnostic = diagnostic

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
                // swiftlint:disable line_length
                Text(
                    String(
                        localized:
                            "launchDiagnosticServiceRegistered \(diagnostic.serviceRegistered ? String(localized: "yes") : String(localized: "no"))"
                    ))
                // swiftlint:enable line_length
                Text(String(localized: "launchDiagnosticCliPath \(diagnostic.cliPath ?? String(localized: "notFound"))"))
                Text(
                    String(
                        localized:
                            "launchDiagnosticPlistFound \(diagnostic.plistFound ? String(localized: "yes") : String(localized: "no"))"))
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
                if diagnostic.cliPath == nil && !diagnostic.plistFound {
                    Link("installContainerCLI",
                         destination: URL(string: "https://github.com/apple/container")!)
                }
            }
        } else {
            Text(error?.localizedDescription ?? String(localized: "unknownError"))
        }
    }
}
