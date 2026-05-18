//
//  DialogStatusTests.swift
//  CraneTests
//

import SwiftUI
import XCTest

@testable import Crane

final class DialogStatusTests: XCTestCase {
    func testIdleIsNotWorkingNotError() {
        let status: DialogStatus = .idle
        XCTAssertFalse(status.isWorking)
        XCTAssertFalse(status.isError)
    }

    func testWorkingIsWorking() {
        let status: DialogStatus = .working("foo")
        XCTAssertTrue(status.isWorking)
        XCTAssertFalse(status.isError)
    }

    func testErrorIsError() {
        let status: DialogStatus = .error("boom")
        XCTAssertFalse(status.isWorking)
        XCTAssertTrue(status.isError)
    }

    func testSuccessIsNeither() {
        let status: DialogStatus = .success
        XCTAssertFalse(status.isWorking)
        XCTAssertFalse(status.isError)
    }

    func testEquality() {
        XCTAssertEqual(DialogStatus.idle, .idle)
        XCTAssertEqual(DialogStatus.working("x"), .working("x"))
        XCTAssertEqual(DialogStatus.error("e"), .error("e"))
        XCTAssertNotEqual(DialogStatus.error("a"), .error("b"))
        XCTAssertEqual(DialogStatus.success, .success)
    }
}
