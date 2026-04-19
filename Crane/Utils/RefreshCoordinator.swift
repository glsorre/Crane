import Foundation
import os.log

@MainActor
final class RefreshCoordinator {
    static let shared = RefreshCoordinator()
    private init() {}

    private func resetAllPolling() {
        ContainersStore.shared.resetPolling?()
        ImagesStore.shared.resetPolling?()
        NetworksStore.shared.resetPolling?()
        VolumesStore.shared.resetPolling?()
    }

    func containerMutated() {
        Task {
            do {
                _ = try await ContainersStore.shared.collect()
            } catch {
                Logger.crane.warning("containerMutated refresh failed: \(error.localizedDescription)")
            }
            resetAllPolling()
        }
    }

    func imageMutated() {
        Task {
            do {
                _ = try await ImagesStore.shared.collect()
                _ = try await ContainersStore.shared.collect()
            } catch {
                Logger.crane.warning("imageMutated refresh failed: \(error.localizedDescription)")
            }
            resetAllPolling()
        }
    }

    func networkMutated() {
        Task {
            do {
                _ = try await NetworksStore.shared.collect()
            } catch {
                Logger.crane.warning("networkMutated refresh failed: \(error.localizedDescription)")
            }
            resetAllPolling()
        }
    }

    func volumeMutated() {
        Task {
            do {
                _ = try await VolumesStore.shared.collect()
            } catch {
                Logger.crane.warning("volumeMutated refresh failed: \(error.localizedDescription)")
            }
            resetAllPolling()
        }
    }
}
