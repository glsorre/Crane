import Foundation
import os.log

func startPolling(
    interval: @escaping () -> Int,
    isVisible: @escaping @Sendable () -> Bool = { PollingVisibility.isVisible },
    onError: @escaping @Sendable (Error) -> Void = { _ in },
    work: @escaping () async throws -> Void
) -> Task<Void, Never> {
    Task {
        while !Task.isCancelled {
            if isVisible() {
                do {
                    try await work()
                } catch {
                    Logger.crane.warning("Polling error: \(error.localizedDescription)")
                    onError(error)
                }
            }
            try? await Task.sleep(for: .seconds(max(interval(), 1)))
        }
    }
}

// apple/container exposes no lifecycle event stream as of macOS 26 SDK; polling is required.
// See SPM checkout: Sources/Services/ContainerAPIService/Client/{ContainerClient,ClientImage,NetworkClient,ClientVolume}.swift
func startAdaptivePolling(
    baseInterval: @escaping () -> Int,
    maxInterval: @escaping () -> Int,
    isVisible: @escaping @Sendable () -> Bool = { PollingVisibility.isVisible },
    onError: @escaping @Sendable (Error) -> Void = { _ in },
    work: @escaping () async throws -> Bool
) -> (task: Task<Void, Never>, reset: @Sendable () -> Void) {
    let currentInterval = OSAllocatedUnfairLock(initialState: 0)

    let reset: @Sendable () -> Void = {
        currentInterval.withLock { $0 = 0 }
    }

    let task = Task {
        while !Task.isCancelled {
            let base = max(baseInterval(), 1)
            let maxI = max(maxInterval(), base)

            let interval: Int = currentInterval.withLock { current in
                if current == 0 { current = base }
                return current
            }

            if isVisible() {
                var changed = false
                do {
                    changed = try await work()
                } catch {
                    Logger.crane.warning("Polling error: \(error.localizedDescription)")
                    onError(error)
                }

                let didChange = changed
                currentInterval.withLock { current in
                    if didChange {
                        current = base
                    } else {
                        current = min(current * 2, maxI)
                    }
                }

                try? await Task.sleep(for: .seconds(interval))
            } else {
                // Backgrounded: sleep at max interval, do not advance backoff.
                try? await Task.sleep(for: .seconds(maxI))
            }
        }
    }

    return (task, reset)
}
