import SwiftUI
import XCTest

@testable import Crane

final class LogThemeTests: XCTestCase {
    func testAllCasesHaveDisplayNames() {
        for theme in LogTheme.allCases {
            XCTAssertFalse(theme.displayName.isEmpty, "Missing display name for \(theme)")
        }
    }

    func testAllCasesDistinctRawValues() {
        let raws = LogTheme.allCases.map(\.rawValue)
        XCTAssertEqual(Set(raws).count, LogTheme.allCases.count, "Duplicate raw values in LogTheme")
    }

    func testDefaultThemeUsesSystemColors() {
        let light = LogTheme.default.lightPalette()
        let dark = LogTheme.default.darkPalette()
        XCTAssertEqual(light.fatal, NSColor.systemRed)
        XCTAssertEqual(dark.fatal, NSColor.systemRed)
        XCTAssertEqual(light.warn, NSColor.systemOrange)
        XCTAssertEqual(dark.warn, NSColor.systemOrange)
    }

    func testPaletteColorForLevel() {
        let p = LogTheme.monokai.lightPalette()
        XCTAssertEqual(p.color(for: .fatal), p.fatal)
        XCTAssertEqual(p.color(for: .error), p.error)
        XCTAssertEqual(p.color(for: .warn), p.warn)
        XCTAssertEqual(p.color(for: .info), p.info)
        XCTAssertEqual(p.color(for: .debug), p.debug)
        XCTAssertEqual(p.color(for: .trace), p.trace)
        XCTAssertEqual(p.color(for: nil), p.info)
    }

    func testMonokaiAndSolarizedDiffer() {
        XCTAssertNotEqual(
            LogTheme.monokai.darkPalette().fatal,
            LogTheme.solarized.darkPalette().fatal
        )
    }

    func testRawValueRoundTrip() {
        for theme in LogTheme.allCases {
            XCTAssertEqual(LogTheme(rawValue: theme.rawValue), theme)
        }
        XCTAssertNil(LogTheme(rawValue: "nonexistent"))
    }

    func testLightAndDarkPalettesAreNotEmpty() {
        // Sanity: every theme's palettes return a non-nil NSColor for every level.
        for theme in LogTheme.allCases {
            for palette in [theme.lightPalette(), theme.darkPalette()] {
                for level in LogLevel.allCases {
                    let color = palette.color(for: level)
                    // NSColor from hex always has a non-nil underlying CGColor; the
                    // type system enforces non-nil. Just exercise the access path.
                    XCTAssertNotNil(color.cgColor, "Missing CGColor for \(theme).\(level)")
                }
                // Background must be non-nil too.
                XCTAssertNotNil(palette.background.cgColor, "Missing background for \(theme)")
            }
        }
    }

    func testDefaultThemeUsesSystemBackground() {
        XCTAssertEqual(LogTheme.default.lightPalette().background, NSColor.textBackgroundColor)
        XCTAssertEqual(LogTheme.default.darkPalette().background, NSColor.textBackgroundColor)
    }

    func testSolarizedBackgroundsDifferByMode() {
        XCTAssertNotEqual(
            LogTheme.solarized.lightPalette().background,
            LogTheme.solarized.darkPalette().background
        )
    }
}
