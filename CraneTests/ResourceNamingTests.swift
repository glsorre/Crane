import XCTest

@testable import Crane

final class ResourceNamingTests: XCTestCase {
    func testEmptyRejected() {
        XCTAssertFalse(ResourceNaming.isValidResourceName(""))
    }

    func testSingleAlnum() {
        XCTAssertTrue(ResourceNaming.isValidResourceName("a"))
        XCTAssertTrue(ResourceNaming.isValidResourceName("Z"))
        XCTAssertTrue(ResourceNaming.isValidResourceName("0"))
        XCTAssertTrue(ResourceNaming.isValidResourceName("9"))
    }

    func testSinglePunctuationRejected() {
        XCTAssertFalse(ResourceNaming.isValidResourceName("-"))
        XCTAssertFalse(ResourceNaming.isValidResourceName("."))
        XCTAssertFalse(ResourceNaming.isValidResourceName("_"))
    }

    func testLeadingTrailingPunctuationRejected() {
        XCTAssertFalse(ResourceNaming.isValidResourceName("-abc"))
        XCTAssertFalse(ResourceNaming.isValidResourceName(".abc"))
        XCTAssertFalse(ResourceNaming.isValidResourceName("_abc"))
        XCTAssertFalse(ResourceNaming.isValidResourceName("abc-"))
        XCTAssertFalse(ResourceNaming.isValidResourceName("abc."))
        XCTAssertFalse(ResourceNaming.isValidResourceName("abc_"))
    }

    func testInteriorPunctuationAccepted() {
        XCTAssertTrue(ResourceNaming.isValidResourceName("a-b"))
        XCTAssertTrue(ResourceNaming.isValidResourceName("a.b"))
        XCTAssertTrue(ResourceNaming.isValidResourceName("a_b"))
        XCTAssertTrue(ResourceNaming.isValidResourceName("foo-bar.baz_qux"))
    }

    func testMixedCaseAndDigits() {
        XCTAssertTrue(ResourceNaming.isValidResourceName("MyContainer1"))
        XCTAssertTrue(ResourceNaming.isValidResourceName("alpine123"))
    }

    func testInvalidCharsRejected() {
        XCTAssertFalse(ResourceNaming.isValidResourceName("a/b"))
        XCTAssertFalse(ResourceNaming.isValidResourceName("a b"))
        XCTAssertFalse(ResourceNaming.isValidResourceName("a@b"))
        XCTAssertFalse(ResourceNaming.isValidResourceName("a:b"))
        XCTAssertFalse(ResourceNaming.isValidResourceName("a#b"))
        XCTAssertFalse(ResourceNaming.isValidResourceName("café"))
    }

    func testMaxLength() {
        let len254 = String(repeating: "a", count: 254)
        let len255 = String(repeating: "a", count: 255)
        XCTAssertTrue(ResourceNaming.isValidResourceName(len254))
        XCTAssertFalse(ResourceNaming.isValidResourceName(len255))
    }
}
