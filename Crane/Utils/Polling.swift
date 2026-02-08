import Foundation
import os.log

func startPolling(interval: @escaping () -> Int, work: @escaping () async throws -> Void) -> Task<Void, Never> {
    Task {
        while !Task.isCancelled {
            do { try await work() }
            catch { Logger.crane.warning("Polling error: \(error.localizedDescription)") }
            try? await Task.sleep(for: .seconds(max(interval(), 1)))
        }
    }
}

func startAdaptivePolling(
    baseInterval: @escaping () -> Int,
    maxInterval: @escaping () -> Int,
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

            var changed = false
            do { changed = try await work() }
            catch { Logger.crane.warning("Polling error: \(error.localizedDescription)") }

            currentInterval.withLock { current in
                if changed {
                    current = base
                } else {
                    current = min(current * 2, maxI)
                }
            }

            try? await Task.sleep(for: .seconds(interval))
        }
    }

    return (task, reset)
}
