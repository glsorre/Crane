//
//  FetchProgressTests.swift
//  CraneTests
//
//  Unit tests for `FetchProgress.apply(_:)` over the full
//  `ProgressUpdateEvent` enum, plus the `fraction` / `bytesDescription`
//  / `itemsDescription` computed properties.
//
//  Pure-logic tests; no SDK, no apiserver, no async. The model is the
//  in-app receiver for the SDK's `progressUpdate` callback, so locking
//  it down here is enough to catch regressions in the consumer side
//  (the producer side is the SDK itself, which we don't test).
//

import TerminalProgress
import XCTest

@testable import Crane

final class FetchProgressTests: XCTestCase {
    private var progress: FetchProgress!

    override func setUp() async throws {
        try await super.setUp()
        progress = FetchProgress()
    }

    // MARK: - setDescription / setSubDescription / setItemsName

    func testSetDescriptionUpdates() {
        progress.apply([.setDescription("fetching layers")])
        XCTAssertEqual(progress.fetchDescription, "fetching layers")
    }

    func testSetSubDescriptionUpdates() {
        progress.apply([.setSubDescription("layer 3 of 7")])
        XCTAssertEqual(progress.subDescription, "layer 3 of 7")
    }

    func testSetItemsNameUpdates() {
        progress.apply([.setItemsName("layers")])
        XCTAssertEqual(progress.itemsName, "layers")
    }

    // MARK: - tasks: add / set

    func testAddTasksAccumulates() {
        progress.apply([.addTasks(2), .addTasks(3)])
        XCTAssertEqual(progress.tasks, 5)
    }

    func testSetTasksReplacesNotAccumulates() {
        progress.apply([.addTasks(5), .setTasks(1)])
        XCTAssertEqual(progress.tasks, 1)
    }

    // MARK: - totalTasks: add / set

    func testAddTotalTasksAccumulates() {
        progress.apply([.addTotalTasks(4), .addTotalTasks(6)])
        XCTAssertEqual(progress.totalTasks, 10)
    }

    func testSetTotalTasksReplaces() {
        progress.apply([.addTotalTasks(10), .setTotalTasks(7)])
        XCTAssertEqual(progress.totalTasks, 7)
    }

    // MARK: - items: add / set

    func testAddItemsAccumulates() {
        progress.apply([.addItems(1), .addItems(2), .addItems(3)])
        XCTAssertEqual(progress.items, 6)
    }

    func testSetItemsReplaces() {
        progress.apply([.addItems(10), .setItems(4)])
        XCTAssertEqual(progress.items, 4)
    }

    // MARK: - totalItems: add / set

    func testAddTotalItemsAccumulates() {
        progress.apply([.addTotalItems(2), .addTotalItems(3)])
        XCTAssertEqual(progress.totalItems, 5)
    }

    func testSetTotalItemsReplaces() {
        progress.apply([.addTotalItems(9), .setTotalItems(4)])
        XCTAssertEqual(progress.totalItems, 4)
    }

    // MARK: - size: add / set

    func testAddSizeAccumulatesInt64() {
        progress.apply([.addSize(1_000), .addSize(2_500)])
        XCTAssertEqual(progress.size, 3_500)
    }

    func testSetSizeReplacesInt64() {
        progress.apply([.addSize(9_999), .setSize(123)])
        XCTAssertEqual(progress.size, 123)
    }

    // MARK: - totalSize: add / set

    func testAddTotalSizeAccumulatesInt64() {
        progress.apply([.addTotalSize(50_000_000), .addTotalSize(25_000_000)])
        XCTAssertEqual(progress.totalSize, 75_000_000)
    }

    func testSetTotalSizeReplacesInt64() {
        progress.apply([.addTotalSize(9_999), .setTotalSize(42_000)])
        XCTAssertEqual(progress.totalSize, 42_000)
    }

    // MARK: - custom

    func testCustomStoresValue() {
        progress.apply([.custom("etag:abc123")])
        XCTAssertEqual(progress.custom, "etag:abc123")
    }

    func testCustomOverwritesPrevious() {
        progress.apply([.custom("first"), .custom("second")])
        XCTAssertEqual(progress.custom, "second")
    }

    // MARK: - apply(_:) is order-independent across event types

    func testMixedBatchAppliesAllEvents() {
        progress.apply([
            .setDescription("pulling"),
            .addTasks(1),
            .addTotalTasks(1),
            .addItems(1),
            .addTotalItems(5),
            .addSize(1_024),
            .addTotalSize(5_120),
            .setSubDescription("manifest"),
            .setItemsName("blobs"),
            .custom("digest:sha256:deadbeef"),
        ])
        XCTAssertEqual(progress.fetchDescription, "pulling")
        XCTAssertEqual(progress.subDescription, "manifest")
        XCTAssertEqual(progress.itemsName, "blobs")
        XCTAssertEqual(progress.tasks, 1)
        XCTAssertEqual(progress.totalTasks, 1)
        XCTAssertEqual(progress.items, 1)
        XCTAssertEqual(progress.totalItems, 5)
        XCTAssertEqual(progress.size, 1_024)
        XCTAssertEqual(progress.totalSize, 5_120)
        XCTAssertEqual(progress.custom, "digest:sha256:deadbeef")
    }

    // MARK: - fraction: prefer size/totalSize, fall back to items/totalItems

    func testFractionNilWhenNoTotalKnown() {
        progress.apply([.addSize(100)])
        XCTAssertNil(progress.fraction)
    }

    func testFractionFromSize() {
        progress.apply([.addSize(25), .addTotalSize(100)])
        XCTAssertEqual(progress.fraction, 0.25)
    }

    func testFractionPrefersSizeOverItems() {
        // Both known; size wins per the model's contract.
        progress.apply([
            .addSize(50),
            .addTotalSize(100),
            .addItems(2),
            .addTotalItems(10),
        ])
        XCTAssertEqual(progress.fraction, 0.5)
    }

    func testFractionFromItemsWhenSizeUnknown() {
        progress.apply([.addItems(3), .addTotalItems(4)])
        XCTAssertEqual(progress.fraction, 0.75)
    }

    func testFractionClampedToOne() {
        progress.apply([.addSize(200), .addTotalSize(100)])
        XCTAssertEqual(progress.fraction, 1.0)
    }

    func testFractionFromSetValues() {
        progress.apply([.setSize(123), .setTotalSize(456)])
        // 123/456 ≈ 0.2697
        XCTAssertEqual(progress.fraction ?? 0, 123.0 / 456.0, accuracy: 1e-9)
    }

    // MARK: - bytesDescription

    func testBytesDescriptionNilWhenNothingObserved() {
        XCTAssertNil(progress.bytesDescription)
    }

    func testBytesDescriptionShowsCurrentOnly() {
        progress.apply([.addSize(1_024)])
        let desc = progress.bytesDescription ?? ""
        XCTAssertTrue(desc.contains("1"), "expected a KB-scale formatter output, got: \(desc)")
    }

    func testBytesDescriptionShowsCurrentAndTotal() {
        progress.apply([.addSize(50 * 1_024 * 1_024), .addTotalSize(200 * 1_024 * 1_024)])
        let desc = progress.bytesDescription ?? ""
        XCTAssertTrue(desc.contains("/"), "expected `current / total` form, got: \(desc)")
    }

    // MARK: - itemsDescription

    func testItemsDescriptionNilWhenTotalUnknown() {
        progress.apply([.addItems(2)])
        XCTAssertNil(progress.itemsDescription)
    }

    func testItemsDescriptionUsesItemsName() {
        progress.apply([.setItemsName("layers"), .addItems(2), .addTotalItems(5)])
        XCTAssertEqual(progress.itemsDescription, "2/5 layers")
    }
}
