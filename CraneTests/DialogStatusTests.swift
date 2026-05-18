//
//  DialogStatusTests.swift
//  CraneTests
//

import SwiftUI
import XCTest

@testable import Crane

final class DialogStatusTests: XCTestCase {
    func testIdleIsNotWorkingNotError() {
        let s: DialogStatus = .idle
        XCTAssertFalse(s.isWorking)
        XCTAssertFalse(s.isError)
    }

    func testWorkingIsWorking() {
        let s: DialogStatus = .working("foo")
        XCTAssertTrue(s.isWorking)
        XCTAssertFalse(s.isError)
    }

    func testErrorIsError() {
        let s: DialogStatus = .error("boom")
        XCTAssertFalse(s.isWorking)
        XCTAssertTrue(s.isError)
    }

    func testSuccessIsNeither() {
        let s: DialogStatus = .success
        XCTAssertFalse(s.isWorking)
        XCTAssertFalse(s.isError)
    }

    func testEquality() {
        XCTAssertEqual(DialogStatus.idle, .idle)
        XCTAssertEqual(DialogStatus.working("x"), .working("x"))
        XCTAssertEqual(DialogStatus.error("e"), .error("e"))
        XCTAssertNotEqual(DialogStatus.error("a"), .error("b"))
        XCTAssertEqual(DialogStatus.success, .success)
    }
}
