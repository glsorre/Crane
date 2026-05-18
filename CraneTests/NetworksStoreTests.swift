import ContainerAPIClient
import ContainerResource
import XCTest

@testable import Crane

final class NetworksStoreTests: CraneTestBase {
    func testCollect() async throws {
        let networks = await MainActor.run { stores.networks }
        try await networks.collect()
    }

    func testCreateAndRemoveNetwork() async throws {
        let networkID = uniqueName()
        let networks = await MainActor.run { stores.networks }

        // Create
        try await networks.createNetwork(id: networkID)

        // Verify present
        let found = await MainActor.run { networks.networks.contains { $0.id == networkID } }
        XCTAssertTrue(found, "Network should be in store after creation")

        // Remove
        await networks.removeNetwork(id: networkID)

        // Verify gone
        let stillThere = await MainActor.run { networks.networks.contains { $0.id == networkID } }
        XCTAssertFalse(stillThere, "Network should be removed from store")
    }
}
