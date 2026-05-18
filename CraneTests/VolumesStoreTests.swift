import ContainerAPIClient
import ContainerResource
import XCTest

@testable import Crane

final class VolumesStoreTests: CraneTestBase {
    func testCollect() async throws {
        let volumes = await MainActor.run { stores.volumes }
        try await volumes.collect()
    }

    func testCreateAndRemoveVolume() async throws {
        let volumeName = uniqueName()
        let volumes = await MainActor.run { stores.volumes }

        // Create
        try await volumes.createVolume(name: volumeName)

        // Verify present
        let found = await MainActor.run { volumes.volumes.contains { $0.id == volumeName } }
        XCTAssertTrue(found, "Volume should be in store after creation")

        // Remove
        await volumes.removeVolume(name: volumeName)

        // Verify gone
        let stillThere = await MainActor.run { volumes.volumes.contains { $0.id == volumeName } }
        XCTAssertFalse(stillThere, "Volume should be removed from store")
    }

    func testCollectSkipsPendingDeletionVolume() async throws {
        let volumeName = uniqueName()
        _ = try await ClientVolume.create(name: volumeName)
        let volumes = await MainActor.run { stores.volumes }
        defer {
            Task { @MainActor in volumes.endPendingDeletion(volumeName) }
        }

        try await volumes.collect()
        let initiallyPresent = await MainActor.run { volumes.volumes.contains { $0.id == volumeName } }
        XCTAssertTrue(initiallyPresent, "Volume should be present before simulating pending deletion")

        await MainActor.run { volumes.beginPendingDeletion(volumeName) }
        try await volumes.collect()

        let stillThere = await MainActor.run { volumes.volumes.contains { $0.id == volumeName } }
        XCTAssertFalse(stillThere, "Pending deletion volumes should not be re-added during refresh")
    }
}
