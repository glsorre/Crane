@testable import Crane
import XCTest

final class CraneErrorTests: XCTestCase {
    func testErrorDescriptionNonNilForAllCases() {
        let allCases: [CraneError] = [
            .notRegistered,
            .notRunning,
            .containerNotFound,
            .imageFetchingFailed,
            .containerStartFailed("x"),
            .containerStopFailed("x"),
            .containerRestartFailed("x"),
            .containerShellFailed("x"),
            .containerRemoveFailed("x"),
            .imageRemoveFailed("x"),
            .imageTagFailed("x"),
            .imageRenameFailed("x"),
            .imageFetchFailed("x"),
            .logStreamFailed("x"),
            .imageBuildFailed("x"),
            .networkRemoveFailed("x"),
            .volumeRemoveFailed("x"),
        ]
        for error in allCases {
            XCTAssertNotNil(error.errorDescription, "Missing description for \(error)")
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }

    func testFatalFlag() {
        XCTAssertTrue(CraneError.notRegistered.fatal)
        XCTAssertTrue(CraneError.notRunning.fatal)
        XCTAssertFalse(CraneError.containerNotFound.fatal)
        XCTAssertFalse(CraneError.imageFetchingFailed.fatal)
        XCTAssertFalse(CraneError.containerStartFailed("x").fatal)
        XCTAssertFalse(CraneError.containerStopFailed("x").fatal)
        XCTAssertFalse(CraneError.containerRemoveFailed("x").fatal)
        XCTAssertFalse(CraneError.imageBuildFailed("x").fatal)
        XCTAssertFalse(CraneError.volumeRemoveFailed("x").fatal)
        XCTAssertFalse(CraneError.networkRemoveFailed("x").fatal)
    }

    func testDetailInterpolation() {
        let token = "unique-detail-token-\(UUID().uuidString)"
        let cases: [CraneError] = [
            .containerStartFailed(token),
            .containerStopFailed(token),
            .containerRemoveFailed(token),
            .imageRemoveFailed(token),
            .imageFetchFailed(token),
            .logStreamFailed(token),
            .imageBuildFailed(token),
            .networkRemoveFailed(token),
            .volumeRemoveFailed(token),
        ]
        for error in cases {
            let desc = error.errorDescription ?? ""
            XCTAssertTrue(desc.contains(token), "Description '\(desc)' missing detail for \(error)")
        }
    }
}
