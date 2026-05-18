import ContainerAPIClient
import ContainerResource
import XCTest

@testable import Crane

final class ImagesStoreTests: CraneTestBase {
    func testCollect() async throws {
        let images = await MainActor.run { stores.images }
        try await images.collect()
    }

    func testFetchAndRemoveImage() async throws {
        let reference = "docker.io/library/alpine:latest"
        let images = await MainActor.run { stores.images }

        // Fetch
        try await images.fetchImage(reference: reference)

        // Verify present
        let normalizedRef = try ClientImage.normalizeReference(reference)
        let found = await MainActor.run { images.images.contains { $0.id == normalizedRef } }
        XCTAssertTrue(found, "Image should be in store after fetch")

        // Remove
        try await images.removeImage(reference: normalizedRef)

        // Verify gone
        let stillThere = await MainActor.run { images.images.contains { $0.id == normalizedRef } }
        XCTAssertFalse(stillThere, "Image should be removed from store")
    }
}
