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
    case gruvbox = "gruvbox"
    case oneLight = "oneLight"
    case nord = "nord"
    case catppuccin = "catppuccin"
    case tokyoNight = "tokyoNight"
    case ayu = "ayu"
    case github = "github"

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
                fatal: NSColor(hex: 0xC8284A),
                error: NSColor(hex: 0xC8284A),
                warn: NSColor(hex: 0xD75F00),
                info: NSColor(hex: 0x272822),
                debug: NSColor(hex: 0x75715E),
                trace: NSColor(hex: 0x9E9E8A),
                background: NSColor(hex: 0xF9F8F5)
            )
        case .oneDark:
            return LogThemePalette(
                fatal: NSColor(hex: 0xE45649),
                error: NSColor(hex: 0xE45649),
                warn: NSColor(hex: 0xA626A4),
                info: NSColor(hex: 0x383A42),
                debug: NSColor(hex: 0xA0A1A7),
                trace: NSColor(hex: 0x696C77),
                background: NSColor(hex: 0xFAFAFA)
            )
        case .dracula:
            return LogThemePalette(
                fatal: NSColor(hex: 0xFF5555),
                error: NSColor(hex: 0xFF79C6),
                warn: NSColor(hex: 0xE5C07B),
                info: NSColor(hex: 0x282A36),
                debug: NSColor(hex: 0x6A7188),
                trace: NSColor(hex: 0x9A9FB0),
                background: NSColor(hex: 0xF8F8F2)
            )
        case .gruvbox:
            return LogThemePalette(
                fatal: NSColor(hex: 0x9D0006),
                error: NSColor(hex: 0xAF3A03),
                warn: NSColor(hex: 0xB57614),
                info: NSColor(hex: 0x3C3836),
                debug: NSColor(hex: 0x7C6F64),
                trace: NSColor(hex: 0x928374),
                background: NSColor(hex: 0xFBF1C7)  // Gruvbox light bg0_h
            )
        case .oneLight:
            return LogThemePalette(
                fatal: NSColor(hex: 0xCA1243),
                error: NSColor(hex: 0xCA1243),
                warn: NSColor(hex: 0xA626A4),
                info: NSColor(hex: 0x383A42),
                debug: NSColor(hex: 0xA0A1A7),
                trace: NSColor(hex: 0x696C77),
                background: NSColor(hex: 0xFAFAFA)
            )
        case .nord:
            return LogThemePalette(
                fatal: NSColor(hex: 0xBF616A),
                error: NSColor(hex: 0xD08770),
                warn: NSColor(hex: 0xEBCB8B),
                info: NSColor(hex: 0x3B4252),
                debug: NSColor(hex: 0x81A1C1),
                trace: NSColor(hex: 0x8FBCBB),
                background: NSColor(hex: 0xECEFF4)  // Nord Snow Storm
            )
        case .catppuccin:
            return LogThemePalette(
                fatal: NSColor(hex: 0xD20F39),
                error: NSColor(hex: 0xD20F39),
                warn: NSColor(hex: 0xDF8E1D),
                info: NSColor(hex: 0x4C4F69),
                debug: NSColor(hex: 0x7C7F93),
                trace: NSColor(hex: 0x9CA0B0),
                background: NSColor(hex: 0xEFF1F5)  // Latte base
            )
        case .tokyoNight:
            return LogThemePalette(
                fatal: NSColor(hex: 0x8C4351),
                error: NSColor(hex: 0x8C4351),
                warn: NSColor(hex: 0x8F5E15),
                info: NSColor(hex: 0x343A52),
                debug: NSColor(hex: 0x96919A),
                trace: NSColor(hex: 0xB5B1B9),
                background: NSColor(hex: 0xD5D6DB)  // Tokyo Night Light bg
            )
        case .ayu:
            return LogThemePalette(
                fatal: NSColor(hex: 0xFF6565),
                error: NSColor(hex: 0xFF6565),
                warn: NSColor(hex: 0xE6B450),
                info: NSColor(hex: 0x5C6166),
                debug: NSColor(hex: 0x828C9A),
                trace: NSColor(hex: 0xA6ADBA),
                background: NSColor(hex: 0xFAFAFA)  // Ayu Light bg
            )
        case .github:
            return LogThemePalette(
                fatal: NSColor(hex: 0xCF222E),
                error: NSColor(hex: 0xCF222E),
                warn: NSColor(hex: 0x9A6700),
                info: NSColor(hex: 0x1F2328),
                debug: NSColor(hex: 0x59636E),
                trace: NSColor(hex: 0x818B98),
                background: NSColor(hex: 0xFFFFFF)  // GitHub Light bg
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
        case .gruvbox:
            return LogThemePalette(
                fatal: NSColor(hex: 0xFB4934),
                error: NSColor(hex: 0xFE80CB),
                warn: NSColor(hex: 0xFABD2F),
                info: NSColor(hex: 0xEBDBB2),
                debug: NSColor(hex: 0xA89984),
                trace: NSColor(hex: 0x928374),
                background: NSColor(hex: 0x282828)  // Gruvbox dark bg0_h
            )
        case .oneLight:
            // oneLight is the light counterpart of oneDark. It is only meaningful
            // as a light-mode selection; reuse the oneDark dark palette as a safe
            // fallback so it still renders readably if chosen for dark mode.
            return LogThemePalette(
                fatal: NSColor(hex: 0xE06C75),
                error: NSColor(hex: 0xE06C75),
                warn: NSColor(hex: 0xE5C07B),
                info: NSColor(hex: 0xABB2BF),
                debug: NSColor(hex: 0x7F848E),
                trace: NSColor(hex: 0x5C6370),
                background: NSColor(hex: 0x282C34)
            )
        case .nord:
            return LogThemePalette(
                fatal: NSColor(hex: 0xBF616A),
                error: NSColor(hex: 0xD08770),
                warn: NSColor(hex: 0xEBCB8B),
                info: NSColor(hex: 0xE5E9F0),
                debug: NSColor(hex: 0x81A1C1),
                trace: NSColor(hex: 0x8FBCBB),
                background: NSColor(hex: 0x2E3440)  // Nord Polar Night
            )
        case .catppuccin:
            return LogThemePalette(
                fatal: NSColor(hex: 0xF38BA8),
                error: NSColor(hex: 0xF38BA8),
                warn: NSColor(hex: 0xF9E2AF),
                info: NSColor(hex: 0xCDD6F4),
                debug: NSColor(hex: 0x7F849C),
                trace: NSColor(hex: 0x6C7086),
                background: NSColor(hex: 0x1E1E2E)  // Mocha base
            )
        case .tokyoNight:
            return LogThemePalette(
                fatal: NSColor(hex: 0xF7768E),
                error: NSColor(hex: 0xF7768E),
                warn: NSColor(hex: 0xE0AF68),
                info: NSColor(hex: 0xC0CAF5),
                debug: NSColor(hex: 0x7AA2F7),
                trace: NSColor(hex: 0x9ECE6E),
                background: NSColor(hex: 0x1A1B26)  // Tokyo Night bg
            )
        case .ayu:
            return LogThemePalette(
                fatal: NSColor(hex: 0xF28779),
                error: NSColor(hex: 0xF28779),
                warn: NSColor(hex: 0xFFD580),
                info: NSColor(hex: 0xCBCCC6),
                debug: NSColor(hex: 0x7E8E91),
                trace: NSColor(hex: 0x5C6770),
                background: NSColor(hex: 0x1F2430)  // Ayu Mirage bg
            )
        case .github:
            return LogThemePalette(
                fatal: NSColor(hex: 0xFF7B72),
                error: NSColor(hex: 0xFF7B72),
                warn: NSColor(hex: 0xFFA657),
                info: NSColor(hex: 0xC9D1D9),
                debug: NSColor(hex: 0x8B949E),
                trace: NSColor(hex: 0x6E7681),
                background: NSColor(hex: 0x0D1117)  // GitHub Dark bg
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
