@testable import Crane
import Foundation
import XCTest

final class StreamReaderTests: XCTestCase {
    private func makeReader(content: String, chunkSize: Int = 4096, delimiter: String = "\n") -> StreamReader? {
        let pipe = Pipe()
        if let data = content.data(using: .utf8) {
            pipe.fileHandleForWriting.write(data)
        }
        try? pipe.fileHandleForWriting.close()
        return StreamReader(
            fileHandle: pipe.fileHandleForReading,
            delimiter: delimiter,
            encoding: .utf8,
            chunkSize: chunkSize
        )
    }

    func testReadsLinesInOrder() throws {
        let reader = try XCTUnwrap(makeReader(content: "one\ntwo\nthree\n"))
        XCTAssertEqual(reader.nextLine(), "one")
        XCTAssertEqual(reader.nextLine(), "two")
        XCTAssertEqual(reader.nextLine(), "three")
        XCTAssertNil(reader.nextLine())
    }

    func testReturnsFinalUnterminatedLine() throws {
        let reader = try XCTUnwrap(makeReader(content: "a\nb"))
        XCTAssertEqual(reader.nextLine(), "a")
        XCTAssertEqual(reader.nextLine(), "b")
        XCTAssertNil(reader.nextLine())
    }

    func testEmptyInputReturnsNil() throws {
        let reader = try XCTUnwrap(makeReader(content: ""))
        XCTAssertNil(reader.nextLine())
    }

    func testSkipLines() throws {
        let reader = try XCTUnwrap(makeReader(content: "a\nb\nc\nd\n"))
        reader.skipLines(2)
        XCTAssertEqual(reader.nextLine(), "c")
    }

    func testSmallChunkAcrossBoundary() throws {
        // Force the delimiter and multi-byte chars to span chunks
        let content = "héllo\nwörld\n"
        let reader = try XCTUnwrap(makeReader(content: content, chunkSize: 3))
        XCTAssertEqual(reader.nextLine(), "héllo")
        XCTAssertEqual(reader.nextLine(), "wörld")
        XCTAssertNil(reader.nextLine())
    }

    func testCustomDelimiter() throws {
        let reader = try XCTUnwrap(makeReader(content: "a\u{0}b\u{0}c\u{0}", delimiter: "\u{0}"))
        XCTAssertEqual(reader.nextLine(), "a")
        XCTAssertEqual(reader.nextLine(), "b")
        XCTAssertEqual(reader.nextLine(), "c")
        XCTAssertNil(reader.nextLine())
    }

    func testCloseIsIdempotent() throws {
        let reader = try XCTUnwrap(makeReader(content: "x\n"))
        reader.close()
        reader.close()
    }
}
