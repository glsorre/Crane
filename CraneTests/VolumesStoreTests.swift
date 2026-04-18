@testable import Crane
import ContainerAPIClient
import ContainerResource
import XCTest

final class VolumesStoreTests: CraneTestBase {
    func testCollect() async throws {
        try await VolumesStore.shared.collect()
    }

    func testCreateAndRemoveVolume() async throws {
        let volumeName = uniqueName()

        // Create
        try await VolumesStore.shared.createVolume(name: volumeName)

        // Verify present
        let found = VolumesStore.shared.volumes.contains { $0.id == volumeName }
        XCTAssertTrue(found, "Volume should be in store after creation")

        // Remove
        await VolumesStore.shared.removeVolume(name: volumeName)

        // Verify gone
        let stillThere = VolumesStore.shared.volumes.contains { $0.id == volumeName }
        XCTAssertFalse(stillThere, "Volume should be removed from store")
    }

    func testCollectSkipsPendingDeletionVolume() async throws {
        let volumeName = uniqueName()
        _ = try await ClientVolume.create(name: volumeName)
        defer { VolumesStore.shared.endPendingDeletion(volumeName) }

        try await VolumesStore.shared.collect()
        XCTAssertTrue(
            VolumesStore.shared.volumes.contains { $0.id == volumeName },
            "Volume should be present before simulating pending deletion"
        )

        VolumesStore.shared.beginPendingDeletion(volumeName)
        try await VolumesStore.shared.collect()

        let stillThere = VolumesStore.shared.volumes.contains { $0.id == volumeName }
        XCTAssertFalse(stillThere, "Pending deletion volumes should not be re-added during refresh")
    }
}
