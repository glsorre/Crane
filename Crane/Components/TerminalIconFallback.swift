//
//  TerminalIconFallback.swift
//  Crane
//
//  SF Symbol fallback used by `TerminalAppCard` when an app icon can't be loaded
//  from the real bundle (app not installed, or the icon has not been registered
//  with Launch Services yet). Each case maps to a hand-picked symbol that hints
//  at the terminal's identity.
//

import SwiftUI

enum TerminalIconFallback {
    static func symbol(for app: TerminalApp) -> String {
        switch app {
        case .systemDefault: return "macwindow"
        case .terminal: return "terminal.fill"
        case .iterm2: return "terminal.fill"
        case .warp: return "bolt.fill"
        case .ghostty: return "moon.stars.fill"
        case .alacritty: return "bolt.horizontal.fill"
        case .kitty: return "cat.fill"
        case .wezterm: return "globe.americas.fill"
        case .hyper: return "tortoise.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
}
