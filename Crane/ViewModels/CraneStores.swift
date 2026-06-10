//
//  CraneStores.swift
//  Crane
//

import Foundation
import Observation
import SwiftUI

nonisolated extension Notification.Name {
    static let craneContainerMutated = Notification.Name("craneContainerMutated")
    static let craneImageMutated = Notification.Name("craneImageMutated")
    static let craneNetworkMutated = Notification.Name("craneNetworkMutated")
    static let craneVolumeMutated = Notification.Name("craneVolumeMutated")
    static let craneRunOnboardingAgain = Notification.Name("craneRunOnboardingAgain")
}

nonisolated enum CraneMutationBus {
    static func postContainerMutated() { NotificationCenter.default.post(name: .craneContainerMutated, object: nil) }
    static func postImageMutated() { NotificationCenter.default.post(name: .craneImageMutated, object: nil) }
    static func postNetworkMutated() { NotificationCenter.default.post(name: .craneNetworkMutated, object: nil) }
    static func postVolumeMutated() { NotificationCenter.default.post(name: .craneVolumeMutated, object: nil) }
}

@MainActor
@Observable
final class CraneStores {
    let app: AppViewModel
    let containers: ContainersStore
    let images: ImagesStore
    let networks: NetworksStore
    let volumes: VolumesStore
    let refresh: RefreshCoordinator
    let build: BuildViewModel
    let run: RunContainerRunner
    let connectionHealth: ConnectionHealthTracker

    init() {
        let app = AppViewModel()
        let onError: @MainActor (CraneError) -> Void = { [weak app] err in
            app?.showError(err)
        }
        let connectionHealth = ConnectionHealthTracker(onConnectionLost: onError)
        let containers = ContainersStore(onError: onError, tracker: connectionHealth)
        let images = ImagesStore(onError: onError, tracker: connectionHealth)
        let networks = NetworksStore(
            onError: onError,
            containersForNetwork: { [weak containers] in containers?.containersForNetwork ?? [:] },
            tracker: connectionHealth
        )
        let volumes = VolumesStore(
            onError: onError,
            containersForVolume: { [weak containers] in containers?.containersForVolume ?? [:] },
            tracker: connectionHealth
        )
        let refresh = RefreshCoordinator(
            containers: containers,
            images: images,
            networks: networks,
            volumes: volumes,
            tracker: connectionHealth
        )

        self.app = app
        self.containers = containers
        self.images = images
        self.networks = networks
        self.volumes = volumes
        self.refresh = refresh
        self.build = BuildViewModel(images: images)
        self.run = RunContainerRunner()
        self.connectionHealth = connectionHealth

        refresh.subscribe()
    }

    func start() {
        containers.start()
        images.start()
        networks.start()
        volumes.start()
    }

    func stop() {
        containers.stop()
        images.stop()
        networks.stop()
        volumes.stop()
    }

    func resetAll() async throws {
        try await containers.reset()
        try await images.reset()
        try await networks.reset()
        try await volumes.reset()
    }

    /// Marks `resource` as the currently visible tab, resets that store's adaptive
    /// backoff, and triggers a one-shot `collect()` so the tab the user just opened
    /// shows fresh data immediately. All other stores pause via `PollingVisibility`.
    func activateTab(_ resource: PolledResource) {
        PollingVisibility.setActive(resource)
        switch resource {
        case .containers:
            containers.resetPolling?()
            Task { @MainActor in _ = try? await containers.collect() }
        case .images:
            images.resetPolling?()
            Task { @MainActor in _ = try? await images.collect() }
        case .networks:
            networks.resetPolling?()
            Task { @MainActor in _ = try? await networks.collect() }
        case .volumes:
            volumes.resetPolling?()
            Task { @MainActor in _ = try? await volumes.collect() }
        }
    }

    static let preview: CraneStores = CraneStores()
}

private struct CraneStoresKey: EnvironmentKey {
    @MainActor static var defaultValue: CraneStores { CraneStores.preview }
}

extension EnvironmentValues {
    var craneStores: CraneStores {
        get { self[CraneStoresKey.self] }
        set { self[CraneStoresKey.self] = newValue }
    }
}
