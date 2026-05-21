import Foundation
import os.log

@MainActor
final class RefreshCoordinator {
    private weak var containers: ContainersStore?
    private weak var images: ImagesStore?
    private weak var networks: NetworksStore?
    private weak var volumes: VolumesStore?
    private weak var tracker: ConnectionHealthTracker?

    private var auxiliaryResets: [ObjectIdentifier: @Sendable () -> Void] = [:]
    private var observers: [NSObjectProtocol] = []

    init(
        containers: ContainersStore,
        images: ImagesStore,
        networks: NetworksStore,
        volumes: VolumesStore,
        tracker: ConnectionHealthTracker? = nil
    ) {
        self.containers = containers
        self.images = images
        self.networks = networks
        self.volumes = volumes
        self.tracker = tracker
    }

    deinit {
        for obs in observers { NotificationCenter.default.removeObserver(obs) }
    }

    func subscribe() {
        let center = NotificationCenter.default
        observers.append(
            center.addObserver(forName: .craneContainerMutated, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.containerMutated() }
            })
        observers.append(
            center.addObserver(forName: .craneImageMutated, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.imageMutated() }
            })
        observers.append(
            center.addObserver(forName: .craneNetworkMutated, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.networkMutated() }
            })
        observers.append(
            center.addObserver(forName: .craneVolumeMutated, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.volumeMutated() }
            })
    }

    func registerReset(token: ObjectIdentifier, reset: @escaping @Sendable () -> Void) {
        auxiliaryResets[token] = reset
    }

    func unregisterReset(token: ObjectIdentifier) {
        auxiliaryResets.removeValue(forKey: token)
    }

    private func resetAllPolling() {
        containers?.resetPolling?()
        images?.resetPolling?()
        networks?.resetPolling?()
        volumes?.resetPolling?()
        for reset in auxiliaryResets.values { reset() }
    }

    func containerMutated() {
        let containers = self.containers
        let tracker = self.tracker
        Task { @MainActor in
            do {
                _ = try await containers?.collect()
            } catch {
                Logger.crane.warning("containerMutated refresh failed: \(error.localizedDescription)")
                tracker?.recordFailure(resource: .containers, error: error)
            }
            resetAllPolling()
        }
    }

    func imageMutated() {
        let containers = self.containers
        let images = self.images
        let tracker = self.tracker
        Task { @MainActor in
            do {
                _ = try await images?.collect()
                _ = try await containers?.collect()
            } catch {
                Logger.crane.warning("imageMutated refresh failed: \(error.localizedDescription)")
                tracker?.recordFailure(resource: .images, error: error)
            }
            resetAllPolling()
        }
    }

    func networkMutated() {
        let networks = self.networks
        let tracker = self.tracker
        Task { @MainActor in
            do {
                _ = try await networks?.collect()
            } catch {
                Logger.crane.warning("networkMutated refresh failed: \(error.localizedDescription)")
                tracker?.recordFailure(resource: .networks, error: error)
            }
            resetAllPolling()
        }
    }

    func volumeMutated() {
        let volumes = self.volumes
        let tracker = self.tracker
        Task { @MainActor in
            do {
                _ = try await volumes?.collect()
            } catch {
                Logger.crane.warning("volumeMutated refresh failed: \(error.localizedDescription)")
                tracker?.recordFailure(resource: .volumes, error: error)
            }
            resetAllPolling()
        }
    }
}
