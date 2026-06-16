//
//  LogTheme.swift
//  Crane
//
//  Log color themes with independent light and dark palettes.
//  Themes can be selected independently for dark and light mode in Settings.
//

import AppKit
import SwiftUI

/// Palette covering all log-level foreground colors plus the view background.
struct LogThemePalette: Equatable {
    let fatal: NSColor
    let error: NSColor
    let warn: NSColor
    let info: NSColor
    let debug: NSColor
    let trace: NSColor
    let background: NSColor

    func color(for level: LogLevel?) -> NSColor {
        switch level {
        case .fatal: return fatal
        case .error: return error
        case .warn: return warn
        case .info: return info
        case .debug: return debug
        case .trace: return trace
        case .none: return info
        }
    }
}

enum LogTheme: String, CaseIterable, Identifiable {
    case `default` = "default"
    case solarized = "solarized"
    case monokai = "monokai"
    case oneDark = "oneDark"
    case dracula = "dracula"

    var id: String { rawValue }

    var displayName: String {
        String(localized: "logTheme.\(rawValue)")
    }

    /// Palette rendered in light mode.
    func lightPalette() -> LogThemePalette {
        switch self {
        case .default:
            return LogThemePalette(
                fatal: .systemRed,
                error: .systemRed,
                warn: .systemOrange,
                info: .controlTextColor,
                debug: .secondaryLabelColor,
                trace: .tertiaryLabelColor,
                background: .textBackgroundColor
            )
        case .solarized:
            return LogThemePalette(
                fatal: NSColor(hex: 0xDC322F),
                error: NSColor(hex: 0xCB4B16),
                warn: NSColor(hex: 0xB58900),
                info: NSColor(hex: 0x586E75),
                debug: NSColor(hex: 0x93A1A1),
                trace: NSColor(hex: 0x657B83),
                background: NSColor(hex: 0xFDF6E3)  // Solarized base3
            )
        case .monokai:
            return LogThemePalette(
                fatal: NSColor(hex: 0xF92672),
                error: NSColor(hex: 0xF92672),
                warn: NSColor(hex: 0xFD971F),
                info: NSColor(hex: 0xF8F8F2),
                debug: NSColor(hex: 0x75715E),
                trace: NSColor(hex: 0x75715E),
                background: NSColor(hex: 0x272822)
            )
        case .oneDark:
            return LogThemePalette(
                fatal: NSColor(hex: 0xE06C75),
                error: NSColor(hex: 0xE06C75),
                warn: NSColor(hex: 0xE5C07B),
                info: NSColor(hex: 0xABB2BF),
                debug: NSColor(hex: 0x7F848E),
                trace: NSColor(hex: 0x5C6370),
                background: NSColor(hex: 0x282C34)
            )
        case .dracula:
            return LogThemePalette(
                fatal: NSColor(hex: 0xFF5555),
                error: NSColor(hex: 0xFF79C6),
                warn: NSColor(hex: 0xF1FA8C),
                info: NSColor(hex: 0xF8F8F2),
                debug: NSColor(hex: 0x6272A4),
                trace: NSColor(hex: 0x6272A4),
                background: NSColor(hex: 0x282A36)
            )
        }
    }

    /// Palette rendered in dark mode.
    func darkPalette() -> LogThemePalette {
        switch self {
        case .default:
            return LogThemePalette(
                fatal: .systemRed,
                error: .systemRed,
                warn: .systemOrange,
                info: .controlTextColor,
                debug: .secondaryLabelColor,
                trace: .tertiaryLabelColor,
                background: .textBackgroundColor
            )
        case .solarized:
            return LogThemePalette(
                fatal: NSColor(hex: 0xF43E3E),
                error: NSColor(hex: 0xF78C6C),
                warn: NSColor(hex: 0xEBCB8B),
                info: NSColor(hex: 0x93A1A1),
                debug: NSColor(hex: 0x657B83),
                trace: NSColor(hex: 0x586E75),
                background: NSColor(hex: 0x002B36)  // Solarized base03
            )
        case .monokai:
            return LogThemePalette(
                fatal: NSColor(hex: 0xF92672),
                error: NSColor(hex: 0xF92672),
                warn: NSColor(hex: 0xFD971F),
                info: NSColor(hex: 0xF8F8F2),
                debug: NSColor(hex: 0x75715E),
                trace: NSColor(hex: 0x75715E),
                background: NSColor(hex: 0x272822)
            )
        case .oneDark:
            return LogThemePalette(
                fatal: NSColor(hex: 0xE06C75),
                error: NSColor(hex: 0xE06C75),
                warn: NSColor(hex: 0xE5C07B),
                info: NSColor(hex: 0xABB2BF),
                debug: NSColor(hex: 0x7F848E),
                trace: NSColor(hex: 0x5C6370),
                background: NSColor(hex: 0x282C34)
            )
        case .dracula:
            return LogThemePalette(
                fatal: NSColor(hex: 0xFF5555),
                error: NSColor(hex: 0xFF79C6),
                warn: NSColor(hex: 0xF1FA8C),
                info: NSColor(hex: 0xF8F8F2),
                debug: NSColor(hex: 0x6272A4),
                trace: NSColor(hex: 0x6272A4),
                background: NSColor(hex: 0x282A36)
            )
        }
    }
}

private extension NSColor {
    /// Hex initializer used by `LogTheme` palettes. Takes 0xRRGGBB.
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
