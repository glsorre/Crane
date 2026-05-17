@testable import Crane
import XCTest

final class DetailsViewModelFormattingTests: XCTestCase {
    // MARK: - formatBytes

    func testFormatBytesKiB() {
        XCTAssertEqual(DetailsViewModel.formatBytes(0), "0.0 KiB")
        XCTAssertEqual(DetailsViewModel.formatBytes(512), "0.5 KiB")
        XCTAssertEqual(DetailsViewModel.formatBytes(1023), "1.0 KiB")
    }

    func testFormatBytesMiB() {
        XCTAssertEqual(DetailsViewModel.formatBytes(1024 * 1024), "1.0 MiB")
        XCTAssertEqual(DetailsViewModel.formatBytes(1024 * 1024 * 5 + 1024 * 1024 / 2), "5.5 MiB")
    }

    func testFormatBytesGiB() {
        XCTAssertEqual(DetailsViewModel.formatBytes(1024 * 1024 * 1024), "1.0 GiB")
        let oneAndHalfGiB: UInt64 = UInt64(1024 * 1024 * 1024) + UInt64(512 * 1024 * 1024)
        XCTAssertEqual(DetailsViewModel.formatBytes(oneAndHalfGiB), "1.5 GiB")
    }

    // MARK: - handleName

    func testHandleNameSingleHandle() {
        // Only one handle (index 0) → falls into the "last" branch → "System"
        XCTAssertEqual(DetailsViewModel.handleName(handleIndex: 0, handleCount: 1), "System")
    }

    func testHandleNameTwoHandles() {
        XCTAssertEqual(DetailsViewModel.handleName(handleIndex: 0, handleCount: 2), "Process")
        XCTAssertEqual(DetailsViewModel.handleName(handleIndex: 1, handleCount: 2), "System")
    }

    func testHandleNameMultipleProcesses() {
        XCTAssertEqual(DetailsViewModel.handleName(handleIndex: 0, handleCount: 4), "Process")
        XCTAssertEqual(DetailsViewModel.handleName(handleIndex: 1, handleCount: 4), "Process 2")
        XCTAssertEqual(DetailsViewModel.handleName(handleIndex: 2, handleCount: 4), "Process 3")
        XCTAssertEqual(DetailsViewModel.handleName(handleIndex: 3, handleCount: 4), "System")
    }
}
