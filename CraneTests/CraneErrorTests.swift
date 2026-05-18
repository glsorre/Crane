import XCTest

@testable import Crane

final class CraneErrorTests: XCTestCase {
    private func err(_ token: String) -> Error {
        NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: token])
    }

    func testErrorDescriptionNonNilForAllCases() {
        let token = err("x")
        let allCases: [CraneError] = [
            .notRegistered(diagnostic: .empty),
            .notRunning(diagnostic: .empty),
            .containerNotFound,
            .imageFetchingFailed,
            .containerStartFailed(underlying: token),
            .containerStopFailed(underlying: token),
            .containerRestartFailed(underlying: token),
            .containerShellFailed(underlying: token),
            .containerRemoveFailed(underlying: token),
            .imageRemoveFailed(underlying: token),
            .imageTagFailed(underlying: token),
            .imageRenameFailed(underlying: token),
            .imageFetchFailed(underlying: token),
            .logStreamFailed(underlying: token),
            .imageBuildFailed(underlying: token),
            .networkRemoveFailed(underlying: token),
            .volumeRemoveFailed(underlying: token),
            .pollingFailed(resource: .containers, underlying: token),
            .connectionLost(consecutiveFailures: 3),
        ]
        for error in allCases {
            XCTAssertNotNil(error.errorDescription, "Missing description for \(error)")
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }

    func testFatalFlag() {
        XCTAssertTrue(CraneError.notRegistered(diagnostic: .empty).fatal)
        XCTAssertTrue(CraneError.notRunning(diagnostic: .empty).fatal)
        XCTAssertFalse(CraneError.containerNotFound.fatal)
        XCTAssertFalse(CraneError.imageFetchingFailed.fatal)
        XCTAssertFalse(CraneError.containerStartFailed(underlying: err("x")).fatal)
        XCTAssertFalse(CraneError.containerStopFailed(underlying: err("x")).fatal)
        XCTAssertFalse(CraneError.containerRemoveFailed(underlying: err("x")).fatal)
        XCTAssertFalse(CraneError.imageBuildFailed(underlying: err("x")).fatal)
        XCTAssertFalse(CraneError.volumeRemoveFailed(underlying: err("x")).fatal)
        XCTAssertFalse(CraneError.networkRemoveFailed(underlying: err("x")).fatal)
        XCTAssertFalse(CraneError.connectionLost(consecutiveFailures: 5).fatal)
    }

    func testDetailInterpolation() {
        let token = "unique-detail-token-\(UUID().uuidString)"
        let underlying = err(token)
        let cases: [CraneError] = [
            .containerStartFailed(underlying: underlying),
            .containerStopFailed(underlying: underlying),
            .containerRemoveFailed(underlying: underlying),
            .imageRemoveFailed(underlying: underlying),
            .imageFetchFailed(underlying: underlying),
            .logStreamFailed(underlying: underlying),
            .imageBuildFailed(underlying: underlying),
            .networkRemoveFailed(underlying: underlying),
            .volumeRemoveFailed(underlying: underlying),
            .pollingFailed(resource: .images, underlying: underlying),
        ]
        for error in cases {
            let desc = error.errorDescription ?? ""
            XCTAssertTrue(desc.contains(token), "Description '\(desc)' missing detail for \(error)")
        }
    }
}
