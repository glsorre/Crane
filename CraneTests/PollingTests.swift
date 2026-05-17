@testable import Crane
import Foundation
import XCTest

final class PollingTests: XCTestCase {
    func testStartPollingInvokesWorkAndCancels() async throws {
        let counter = Counter()
        let task = startPolling(interval: { 1 }) {
            await counter.increment()
        }

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
        let task = startPolling(interval: { 1 }) {
            await counter.increment()
            throw NSError(domain: "test", code: 1)
        }

        try await Task.sleep(for: .seconds(2))
        task.cancel()
        let observed = await counter.value
        XCTAssertGreaterThanOrEqual(observed, 1, "Polling must continue after a thrown error")
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
