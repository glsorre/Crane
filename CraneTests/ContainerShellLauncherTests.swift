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
}
