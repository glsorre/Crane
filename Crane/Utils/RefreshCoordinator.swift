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
            try? await ContainersStore.shared.collect()
            resetAllPolling()
        }
    }

    func imageMutated() {
        Task {
            try? await ImagesStore.shared.collect()
            try? await ContainersStore.shared.collect()
            resetAllPolling()
        }
    }

    func networkMutated() {
        Task {
            try? await NetworksStore.shared.collect()
            resetAllPolling()
        }
    }

    func volumeMutated() {
        Task {
            try? await VolumesStore.shared.collect()
            resetAllPolling()
        }
    }
}
