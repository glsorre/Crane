@testable import Crane
import XCTest

final class AppSettingsTests: XCTestCase {
    private var suiteName: String!
    private var originalDefaults: UserDefaults!
    private var testDefaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "crane-tests-\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)
        originalDefaults = AppSettings.defaults
        AppSettings.defaults = testDefaults
    }

    override func tearDown() async throws {
        AppSettings.defaults = originalDefaults
        testDefaults.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    func testRefreshIntervalDefaultClampsToOne() {
        XCTAssertEqual(AppSettings.refreshInterval, 1)
        testDefaults.set(5, forKey: "refreshInterval")
        XCTAssertEqual(AppSettings.refreshInterval, 5)
        testDefaults.set(0, forKey: "refreshInterval")
        XCTAssertEqual(AppSettings.refreshInterval, 1)
    }

    func testMaxPollingIntervalDefault() {
        XCTAssertEqual(AppSettings.maxPollingInterval, 30)
        testDefaults.set(60, forKey: "maxPollingInterval")
        XCTAssertEqual(AppSettings.maxPollingInterval, 60)
    }

    func testLaunchContainerizationServiceDefaultTrue() {
        XCTAssertTrue(AppSettings.launchContainerizationService)
        testDefaults.set(false, forKey: "launchContainerizationFramework")
        XCTAssertFalse(AppSettings.launchContainerizationService)
        testDefaults.set(true, forKey: "launchContainerizationFramework")
        XCTAssertTrue(AppSettings.launchContainerizationService)
    }

    func testPersistentContainerIDsRoundTrip() {
        XCTAssertTrue(AppSettings.persistentContainerIDs.isEmpty)
        AppSettings.persistentContainerIDs = ["a", "b", "c"]
        XCTAssertEqual(AppSettings.persistentContainerIDs, ["a", "b", "c"])
    }

    func testAddPersistentContainerIDIsIdempotent() {
        AppSettings.addPersistentContainerID("alpha")
        AppSettings.addPersistentContainerID("alpha")
        AppSettings.addPersistentContainerID("beta")
        XCTAssertEqual(AppSettings.persistentContainerIDs, ["alpha", "beta"])
    }

    func testRemovePersistentContainerID() {
        AppSettings.persistentContainerIDs = ["x", "y"]
        AppSettings.removePersistentContainerID("x")
        XCTAssertEqual(AppSettings.persistentContainerIDs, ["y"])
        AppSettings.removePersistentContainerID("missing")
        XCTAssertEqual(AppSettings.persistentContainerIDs, ["y"])
    }
}
