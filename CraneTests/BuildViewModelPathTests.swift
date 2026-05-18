import XCTest

@testable import Crane

final class BuildViewModelPathTests: XCTestCase {
    private var context: URL!

    override func setUp() async throws {
        try await super.setUp()
        context = URL(fileURLWithPath: "/tmp/crane-build-test/\(UUID().uuidString)", isDirectory: true)
    }

    func testDefaultsToDockerfile() throws {
        let url = try BuildViewModel.resolveDockerfileURL(context: context, relativePath: "")
        XCTAssertEqual(url.lastPathComponent, "Dockerfile")
        XCTAssertTrue(url.path.hasPrefix(context.standardizedFileURL.path))
    }

    func testWhitespaceOnlyDefaultsToDockerfile() throws {
        let url = try BuildViewModel.resolveDockerfileURL(context: context, relativePath: "   ")
        XCTAssertEqual(url.lastPathComponent, "Dockerfile")
    }

    func testRelativePathInside() throws {
        let url = try BuildViewModel.resolveDockerfileURL(context: context, relativePath: "sub/Dockerfile.dev")
        XCTAssertEqual(url.lastPathComponent, "Dockerfile.dev")
        XCTAssertTrue(url.path.hasPrefix(context.standardizedFileURL.path))
    }

    func testAbsolutePathRejected() {
        XCTAssertThrowsError(
            try BuildViewModel.resolveDockerfileURL(context: context, relativePath: "/etc/passwd")
        )
    }

    func testParentDirectoryEscapeRejected() {
        XCTAssertThrowsError(
            try BuildViewModel.resolveDockerfileURL(context: context, relativePath: "../escape")
        )
    }

    func testDeepParentEscapeRejected() {
        XCTAssertThrowsError(
            try BuildViewModel.resolveDockerfileURL(context: context, relativePath: "sub/../../escape")
        )
    }
}
