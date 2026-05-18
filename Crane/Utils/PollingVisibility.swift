//
//  PollingVisibility.swift
//  Crane
//

import Foundation
import os

/// Thread-safe gating for polling tasks.
///
/// Two independent axes:
///   * Scene active — set from `CraneView`'s `scenePhase` observer. When the app is
///     backgrounded, no store should poll regardless of which tab is selected.
///   * Active resource — the tab the user is currently looking at. Only the store
///     that backs the active tab polls; the others sleep at their max interval.
///
/// Polling closures call `isVisible(for:)` to combine both axes.
/// Mutated from the MainActor; read from polling task closures.
enum PollingVisibility {
    private static let sceneState = OSAllocatedUnfairLock(initialState: true)
    private static let activeState = OSAllocatedUnfairLock<PolledResource?>(initialState: .containers)

    static var isSceneActive: Bool {
        sceneState.withLock { $0 }
    }

    static func setSceneActive(_ value: Bool) {
        sceneState.withLock { $0 = value }
    }

    /// Returns true when the scene is active AND `resource` matches the currently active tab.
    static func isVisible(for resource: PolledResource) -> Bool {
        guard sceneState.withLock({ $0 }) else { return false }
        return activeState.withLock { $0 == resource }
    }

    /// Marks one resource as the active tab. All others become inactive.
    /// Pass `nil` to deactivate every resource (e.g. during teardown).
    static func setActive(_ resource: PolledResource?) {
        activeState.withLock { $0 = resource }
    }

    static var activeResource: PolledResource? {
        activeState.withLock { $0 }
    }

    /// Legacy callers that only care about the scene-active axis.
    static var isVisible: Bool { isSceneActive }

    /// Legacy shim — only the scene axis is affected. Per-resource gating is handled by `setActive(_:)`.
    static func setVisible(_ value: Bool) {
        setSceneActive(value)
    }
}
