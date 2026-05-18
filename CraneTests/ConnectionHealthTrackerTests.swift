import XCTest

@testable import Crane

@MainActor
final class ConnectionHealthTrackerTests: XCTestCase {
    private func err() -> Error {
        NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
    }

    func testStartsHealthy() {
        let tracker = ConnectionHealthTracker()
        XCTAssertEqual(tracker.health, .healthy)
        XCTAssertNil(tracker.lastError)
        XCTAssertEqual(tracker.consecutiveFailures, 0)
    }

    func testFirstFailureMarksDegraded() {
        let tracker = ConnectionHealthTracker()
        tracker.recordFailure(resource: .containers, error: err())
        XCTAssertEqual(tracker.health, .degraded)
        XCTAssertEqual(tracker.consecutiveFailures, 1)
        XCTAssertNotNil(tracker.lastError)
    }

    func testReachingLostThresholdFiresOnce() {
        var lostCount = 0
        let tracker = ConnectionHealthTracker(
            degradedThreshold: 1,
            lostThreshold: 3,
            onConnectionLost: { _ in lostCount += 1 }
        )
        tracker.recordFailure(resource: .containers, error: err())
        XCTAssertEqual(lostCount, 0)
        tracker.recordFailure(resource: .images, error: err())
        XCTAssertEqual(lostCount, 0)
        tracker.recordFailure(resource: .networks, error: err())
        XCTAssertEqual(tracker.health, .lost)
        XCTAssertEqual(lostCount, 1)
        tracker.recordFailure(resource: .volumes, error: err())
        XCTAssertEqual(lostCount, 1, "Should not re-fire while still .lost")
    }

    func testSuccessClearsState() {
        let tracker = ConnectionHealthTracker()
        tracker.recordFailure(resource: .containers, error: err())
        tracker.recordFailure(resource: .containers, error: err())
        tracker.recordSuccess()
        XCTAssertEqual(tracker.health, .healthy)
        XCTAssertEqual(tracker.consecutiveFailures, 0)
        XCTAssertNil(tracker.lastError)
    }

    func testRecoveryAndRelapseFiresAgain() {
        var lostCount = 0
        let tracker = ConnectionHealthTracker(
            degradedThreshold: 1,
            lostThreshold: 2,
            onConnectionLost: { _ in lostCount += 1 }
        )
        tracker.recordFailure(resource: .containers, error: err())
        tracker.recordFailure(resource: .containers, error: err())
        XCTAssertEqual(lostCount, 1)
        tracker.recordSuccess()
        XCTAssertEqual(tracker.health, .healthy)
        tracker.recordFailure(resource: .containers, error: err())
        tracker.recordFailure(resource: .containers, error: err())
        XCTAssertEqual(lostCount, 2)
    }
}
