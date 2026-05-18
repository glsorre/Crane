import ContainerResource
import SwiftUI
import XCTest

@testable import Crane

final class RuntimeStatusExtensionsTests: XCTestCase {
    func testGetDescription() {
        XCTAssertEqual(RuntimeStatus.running.getDescription(), "Running")
        XCTAssertEqual(RuntimeStatus.stopped.getDescription(), "Stopped")
        XCTAssertEqual(RuntimeStatus.stopping.getDescription(), "Stopping")
    }

    func testGetColor() {
        XCTAssertEqual(RuntimeStatus.running.getColor(), Color.green)
        XCTAssertEqual(RuntimeStatus.stopped.getColor(), Color.red)
        XCTAssertEqual(RuntimeStatus.stopping.getColor(), Color.yellow)
    }
}
