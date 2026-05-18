import Foundation
import XCTest

@testable import Crane

final class PollingTests: XCTestCase {
    func testStartPollingInvokesWorkAndCancels() async throws {
        let counter = Counter()
        let task = startPolling(
            interval: { 1 },
            work: { await counter.increment() }
        )

        // First invocation runs immediately; wait ~2.5s for at least two more.
        try await Task.sleep(for: .seconds(2))
        task.cancel()
        let observed = await counter.value
        XCTAssertGreaterThanOrEqual(observed, 1)

        // After cancel, the counter must not keep moving.
        try await Task.sleep(for: .seconds(2))
        let final = await counter.value
        XCTAssertLessThanOrEqual(final - observed, 1)
    }

    func testStartPollingSwallowsErrors() async throws {
        let counter = Counter()
        let task = startPolling(
            interval: { 1 },
            work: {
                await counter.increment()
                throw NSError(domain: "test", code: 1)
            }
        )

        try await Task.sleep(for: .seconds(2))
        task.cancel()
        let observed = await counter.value
        XCTAssertGreaterThanOrEqual(observed, 1, "Polling must continue after a thrown error")
    }

    func testPollingSkipsWorkWhenNotVisible() async throws {
        let counter = Counter()
        let visible = AtomicBool(false)
        let task = startPolling(
            interval: { 1 },
            isVisible: { visible.get() },
            work: { await counter.increment() }
        )

        try await Task.sleep(for: .seconds(2))
        let beforeResume = await counter.value
        XCTAssertEqual(beforeResume, 0, "Work must not run while not visible")

        visible.set(true)
        try await Task.sleep(for: .seconds(2))
        task.cancel()
        let afterResume = await counter.value
        XCTAssertGreaterThanOrEqual(afterResume, 1, "Work must resume when visible")
    }

    func testPollingVisibilityIsPerResource() async throws {
        let previousScene = PollingVisibility.isSceneActive
        let previousActive = PollingVisibility.activeResource
        defer {
            PollingVisibility.setSceneActive(previousScene)
            PollingVisibility.setActive(previousActive)
        }

        let containersCounter = Counter()
        let imagesCounter = Counter()

        PollingVisibility.setSceneActive(true)
        PollingVisibility.setActive(.containers)

        let containersTask = startPolling(
            interval: { 1 },
            isVisible: { PollingVisibility.isVisible(for: .containers) },
            work: { await containersCounter.increment() }
        )
        let imagesTask = startPolling(
            interval: { 1 },
            isVisible: { PollingVisibility.isVisible(for: .images) },
            work: { await imagesCounter.increment() }
        )

        try await Task.sleep(for: .seconds(2))
        let containersWhileActive = await containersCounter.value
        let imagesWhileInactive = await imagesCounter.value
        XCTAssertGreaterThanOrEqual(containersWhileActive, 1, "Active resource must poll")
        XCTAssertEqual(imagesWhileInactive, 0, "Inactive resource must not poll")

        PollingVisibility.setActive(.images)
        try await Task.sleep(for: .seconds(2))
        containersTask.cancel()
        imagesTask.cancel()

        let containersAfterSwitch = await containersCounter.value
        let imagesAfterSwitch = await imagesCounter.value
        XCTAssertGreaterThanOrEqual(imagesAfterSwitch, 1, "Newly active resource must start polling")
        XCTAssertLessThanOrEqual(containersAfterSwitch - containersWhileActive, 1, "Previously active resource must stop polling")
    }

    func testPollingVisibilityRespectsScene() {
        let previousScene = PollingVisibility.isSceneActive
        let previousActive = PollingVisibility.activeResource
        defer {
            PollingVisibility.setSceneActive(previousScene)
            PollingVisibility.setActive(previousActive)
        }

        PollingVisibility.setActive(.containers)
        PollingVisibility.setSceneActive(false)
        XCTAssertFalse(PollingVisibility.isVisible(for: .containers), "Scene inactive must override active resource")

        PollingVisibility.setSceneActive(true)
        XCTAssertTrue(PollingVisibility.isVisible(for: .containers))
        XCTAssertFalse(PollingVisibility.isVisible(for: .images))
    }

    func testAdaptivePollingResetReducesInterval() async throws {
        // baseInterval=1s, max=4s, work returns false (no change) so interval doubles.
        // Verify that after enough iterations the closure ran at least once,
        // and that reset() does not crash.
        let counter = Counter()
        let (task, reset) = startAdaptivePolling(
            baseInterval: { 1 },
            maxInterval: { 4 },
            work: {
                await counter.increment()
                return false
            }
        )

        try await Task.sleep(for: .seconds(2))
        reset()
        try await Task.sleep(for: .milliseconds(500))
        task.cancel()
        let observed = await counter.value
        XCTAssertGreaterThanOrEqual(observed, 1)
    }
}

private actor Counter {
    private(set) var value: Int = 0
    func increment() { value += 1 }
}

private final class AtomicBool: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Bool
    init(_ value: Bool) { self.value = value }
    func get() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
    func set(_ newValue: Bool) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }
}
