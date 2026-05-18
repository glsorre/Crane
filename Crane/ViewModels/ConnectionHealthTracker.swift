//
//  ConnectionHealthTracker.swift
//  Crane
//

import Foundation
import Observation

@MainActor
@Observable
final class ConnectionHealthTracker {
    enum Health: Equatable {
        case healthy
        case degraded
        case lost
    }

    var health: Health = .healthy
    var lastError: CraneError?
    var consecutiveFailures: Int = 0

    let degradedThreshold: Int
    let lostThreshold: Int

    private let onConnectionLost: @MainActor (CraneError) -> Void

    init(
        degradedThreshold: Int = 1,
        lostThreshold: Int = 3,
        onConnectionLost: @escaping @MainActor (CraneError) -> Void = { _ in }
    ) {
        self.degradedThreshold = degradedThreshold
        self.lostThreshold = lostThreshold
        self.onConnectionLost = onConnectionLost
    }

    func recordFailure(resource: PolledResource, error: Error) {
        consecutiveFailures += 1
        lastError = .pollingFailed(resource: resource, underlying: error)
        let prev = health
        if consecutiveFailures >= lostThreshold {
            health = .lost
            if prev != .lost {
                onConnectionLost(.connectionLost(consecutiveFailures: consecutiveFailures))
            }
        } else if consecutiveFailures >= degradedThreshold {
            health = .degraded
        }
    }

    func recordSuccess() {
        consecutiveFailures = 0
        lastError = nil
        health = .healthy
    }
}
