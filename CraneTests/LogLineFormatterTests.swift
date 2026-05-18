@testable import Crane
import XCTest

final class LogLineFormatterTests: XCTestCase {
    func testDetectsBareLevels() {
        XCTAssertEqual(LogLineFormatter.detectLevel(in: "ERROR something bad happened"), .error)
        XCTAssertEqual(LogLineFormatter.detectLevel(in: "WARN nearly bad"), .warn)
        XCTAssertEqual(LogLineFormatter.detectLevel(in: "INFO hello"), .info)
        XCTAssertEqual(LogLineFormatter.detectLevel(in: "DEBUG inner state"), .debug)
        XCTAssertEqual(LogLineFormatter.detectLevel(in: "TRACE fine grained"), .trace)
        XCTAssertEqual(LogLineFormatter.detectLevel(in: "FATAL unrecoverable"), .fatal)
    }

    func testDetectsBracketedLevels() {
        XCTAssertEqual(LogLineFormatter.detectLevel(in: "[ERROR] bad"), .error)
        XCTAssertEqual(LogLineFormatter.detectLevel(in: "[WARN] meh"), .warn)
        XCTAssertEqual(LogLineFormatter.detectLevel(in: "[INFO] ok"), .info)
    }

    func testDetectsAliases() {
        XCTAssertEqual(LogLineFormatter.detectLevel(in: "ERR shorthand"), .error)
        XCTAssertEqual(LogLineFormatter.detectLevel(in: "WARNING full word"), .warn)
        XCTAssertEqual(LogLineFormatter.detectLevel(in: "DBG short debug"), .debug)
    }

    func testCaseInsensitive() {
        XCTAssertEqual(LogLineFormatter.detectLevel(in: "error lowercase"), .error)
        XCTAssertEqual(LogLineFormatter.detectLevel(in: "Warn mixed"), .warn)
    }

    func testLeadingWhitespace() {
        XCTAssertEqual(LogLineFormatter.detectLevel(in: "   ERROR padded"), .error)
        XCTAssertEqual(LogLineFormatter.detectLevel(in: "\t[INFO] tab"), .info)
    }

    func testNoLevel() {
        XCTAssertNil(LogLineFormatter.detectLevel(in: "plain line no level"))
        XCTAssertNil(LogLineFormatter.detectLevel(in: "ERRORSAUCE not a real level"))
        XCTAssertNil(LogLineFormatter.detectLevel(in: ""))
    }

    func testLineNumberPrefix() {
        XCTAssertEqual(LogLineFormatter.lineNumberPrefix(0), "000000")
        XCTAssertEqual(LogLineFormatter.lineNumberPrefix(42), "000042")
        XCTAssertEqual(LogLineFormatter.lineNumberPrefix(999_999), "999999")
    }

    func testTimestampPrefixFormat() {
        // Just verify it produces an HH:mm:ss.SSS-shaped string
        let s = LogLineFormatter.timestampPrefix(for: Date())
        XCTAssertEqual(s.count, 12) // "HH:mm:ss.SSS"
    }
}
