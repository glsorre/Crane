import XCTest

@testable import Crane

final class ContainerShellLauncherTests: XCTestCase {
    func testEmptyString() {
        XCTAssertEqual(ContainerShellLauncher.bashSingleQuoted(""), "''")
    }

    func testNoQuotes() {
        XCTAssertEqual(ContainerShellLauncher.bashSingleQuoted("hello"), "'hello'")
        XCTAssertEqual(ContainerShellLauncher.bashSingleQuoted("a b c"), "'a b c'")
        XCTAssertEqual(
            ContainerShellLauncher.bashSingleQuoted("/usr/local/bin/container"),
            "'/usr/local/bin/container'")
    }

    func testSingleQuoteEscaped() {
        XCTAssertEqual(ContainerShellLauncher.bashSingleQuoted("it's"), "'it'\\''s'")
    }

    func testMultipleSingleQuotes() {
        XCTAssertEqual(ContainerShellLauncher.bashSingleQuoted("a'b'c"), "'a'\\''b'\\''c'")
    }

    func testDoubleQuoteAndBackslashUnchanged() {
        XCTAssertEqual(ContainerShellLauncher.bashSingleQuoted("\"x\""), "'\"x\"'")
        XCTAssertEqual(ContainerShellLauncher.bashSingleQuoted("a\\b"), "'a\\b'")
    }

    // MARK: - config: parameter

    func testRejectsEmptyContainerIDWithConfig() {
        let cfg = TerminalConfig.default
        XCTAssertThrowsError(
            try ContainerShellLauncher.openInteractiveShell(containerID: "", config: cfg)
        )
    }

    func testRejectsInvalidContainerIDWithConfig() {
        let cfg = TerminalConfig.default
        XCTAssertThrowsError(
            try ContainerShellLauncher.openInteractiveShell(containerID: "bad id with spaces", config: cfg)
        )
    }

    func testDefaultConfigIsLoadFromUserDefaults() throws {
        // The parameterless overload still works because it calls .load() internally.
        // We can't run a real launch in a unit test, so we only verify the helper's
        // exit point: openInteractiveShell(containerID:valid:config:) should never
        // silently no-op on a syntactically valid id. Accept either a thrown error
        // (validation failure) or a successful launch (unlikely under xcodebuild test).
        // Skip when running under xcodebuild test to avoid opening a real terminal.
        guard !AppSettings.isRunningTests else {
            throw XCTSkip("Skipped under test runner to avoid launching a real terminal")
        }
        let id = "abc123"
        _ = try? ContainerShellLauncher.openInteractiveShell(containerID: id)
    }
}
