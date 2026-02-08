@testable import Crane
import ContainerAPIClient
import ContainerResource
import XCTest

final class ImagesStoreTests: CraneTestBase {
    func testCollect() async throws {
        try await ImagesStore.shared.collect()
    }

    func testFetchAndRemoveImage() async throws {
        let reference = "docker.io/library/alpine:latest"

        // Fetch
        try await ImagesStore.shared.fetchImage(reference: reference)

        // Verify present
        let normalizedRef = try ClientImage.normalizeReference(reference)
        let found = ImagesStore.shared.images.contains { $0.id == normalizedRef }
        XCTAssertTrue(found, "Image should be in store after fetch")

        // Remove
        try await ImagesStore.shared.removeImage(reference: normalizedRef)

        // Verify gone
        let stillThere = ImagesStore.shared.images.contains { $0.id == normalizedRef }
        XCTAssertFalse(stillThere, "Image should be removed from store")
    }
}
