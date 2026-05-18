import XCTest

@testable import Crane

final class CraneErrorDiagnosticTests: XCTestCase {
    func testSeverityForLaunchErrors() {
        XCTAssertEqual(CraneError.notRegistered(diagnostic: .empty).severity, .fatal)
        XCTAssertEqual(CraneError.notRunning(diagnostic: .empty).severity, .fatal)
    }

    func testSeverityForPollingAndConnection() {
        let err = NSError(domain: "T", code: 1)
        XCTAssertEqual(
            CraneError.pollingFailed(resource: .containers, underlying: err).severity,
            .warning
        )
        XCTAssertEqual(CraneError.connectionLost(consecutiveFailures: 4).severity, .warning)
    }

    func testSeverityForActionErrors() {
        let err = NSError(domain: "T", code: 1)
        XCTAssertEqual(CraneError.containerStartFailed(underlying: err).severity, .error)
        XCTAssertEqual(CraneError.imageBuildFailed(underlying: err).severity, .error)
    }

    func testDiagnosticAccessor() {
        var diag = LaunchDiagnostic()
        diag.serviceRegistered = true
        diag.cliPath = "/opt/homebrew/bin/container"
        let error = CraneError.notRegistered(diagnostic: diag)
        XCTAssertEqual(error.diagnostic?.serviceRegistered, true)
        XCTAssertEqual(error.diagnostic?.cliPath, "/opt/homebrew/bin/container")
        XCTAssertNil(CraneError.containerNotFound.diagnostic)
    }

    func testUnderlyingAccessor() {
        let err = NSError(domain: "TestDomain", code: 42, userInfo: [NSLocalizedDescriptionKey: "msg"])
        let wrapped = CraneError.containerStartFailed(underlying: err)
        let underlying = wrapped.underlyingError as NSError?
        XCTAssertEqual(underlying?.domain, "TestDomain")
        XCTAssertEqual(underlying?.code, 42)
    }

    func testDebugDetailForNSError() {
        let err = NSError(domain: "TestDomain", code: 42)
        let wrapped = CraneError.containerStartFailed(underlying: err)
        XCTAssertEqual(wrapped.debugDetail, "TestDomain #42")
    }

    func testDebugDetailNilWithoutUnderlying() {
        XCTAssertNil(CraneError.containerNotFound.debugDetail)
        XCTAssertNil(CraneError.notRegistered(diagnostic: .empty).debugDetail)
    }
}
