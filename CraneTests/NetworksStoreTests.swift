@testable import Crane
import ContainerAPIClient
import ContainerResource
import XCTest

final class NetworksStoreTests: CraneTestBase {
    func testCollect() async throws {
        try await NetworksStore.shared.collect()
    }

    func testCreateAndRemoveNetwork() async throws {
        let networkID = uniqueName()

        // Create
        try await NetworksStore.shared.createNetwork(id: networkID)

        // Verify present
        let found = NetworksStore.shared.networks.contains { $0.id == networkID }
        XCTAssertTrue(found, "Network should be in store after creation")

        // Remove
        await NetworksStore.shared.removeNetwork(id: networkID)

        // Verify gone
        let stillThere = NetworksStore.shared.networks.contains { $0.id == networkID }
        XCTAssertFalse(stillThere, "Network should be removed from store")
    }
}
