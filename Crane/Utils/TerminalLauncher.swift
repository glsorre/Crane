//
//  TerminalLauncher.swift
//  Crane
//
//  Terminal app picker for `container exec` shells.
//

import AppKit
import Foundation
import os.log

/// Terminal app used to open `container exec` shells. The selection is persisted
/// in `UserDefaults` under the key `terminalApp`; `custom` additionally persists
/// `terminalCustomCommand`.
enum TerminalApp: String, CaseIterable, Identifiable {
    case systemDefault = "systemDefault"
    case terminal = "terminal"
    case iterm2 = "iterm2"
    case warp = "warp"
    case ghostty = "ghostty"
    case alacritty = "alacritty"
    case kitty = "kitty"
    case wezterm = "wezterm"
    case hyper = "hyper"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        String(localized: "terminal.\(rawValue)")
    }

    /// Bundle identifier for the app. Returns `nil` for `.custom` (no app).
    /// `.systemDefault` also returns `nil` because we open the script file with
    /// whatever app macOS has registered for `.command` files.
    var bundleIdentifier: String? {
        switch self {
        case .systemDefault: return nil
        case .terminal: return "com.apple.Terminal"
        case .iterm2: return "com.googlecode.iterm2"
        case .warp: return "dev.warp.Warp-Stable"
        case .ghostty: return "com.mitchellh.ghostty"
        case .alacritty: return "org.alacritty"
        case .kitty: return "net.kovidgoyal.kitty"
        case .wezterm: return "com.github.wez.wezterm"
        case .hyper: return "co.zeit.hyper"
        case .custom: return nil
        }
    }

    /// Whether this terminal expects the script path to be passed after `-e`
    /// (CLI-driven terminals) instead of being opened as a `.command` file
    /// (Terminal.app / iTerm2 / Warp).
    var usesCLIInvocation: Bool {
        switch self {
        case .ghostty, .alacritty, .kitty, .wezterm, .hyper: return true
        case .systemDefault, .terminal, .iterm2, .warp, .custom: return false
        }
    }
}

/// User-facing terminal configuration persisted in `UserDefaults`.
struct TerminalConfig: Equatable {
    var app: TerminalApp
    /// Template used only when `app == .custom`. Supports the `{script}` placeholder.
    var customCommand: String

    static let `default` = TerminalConfig(app: .systemDefault, customCommand: "open -a Terminal {script}")

    /// Load the config from `UserDefaults`, falling back to `default` on missing
    /// or unrecognized values.
    static func load(from defaults: UserDefaults = .standard) -> TerminalConfig {
        let appRaw = defaults.string(forKey: "terminalApp") ?? TerminalApp.systemDefault.rawValue
        let app = TerminalApp(rawValue: appRaw) ?? .systemDefault
        let custom = defaults.string(forKey: "terminalCustomCommand") ?? "open -a Terminal {script}"
        return TerminalConfig(app: app, customCommand: custom)
    }
}

enum TerminalLauncher {
    /// Resolves the on-disk URL for a `TerminalApp`. Returns the app's bundle URL
    /// for GUI apps and the resolved binary path for CLI apps. Returns `nil` if
    /// the app isn't installed.
    static func appURL(for app: TerminalApp) -> URL? {
        guard let bundleId = app.bundleIdentifier else { return nil }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
    }

    /// Validates a config + script path without launching anything. Used by tests
    /// and by `launch` to short-circuit on bad input.
    static func validate(cfg: TerminalConfig, scriptPath: String) throws {
        switch cfg.app {
        case .custom:
            let trimmed = cfg.customCommand.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                throw terminalError(code: 10, message: String(localized: "terminalCustomCommandEmpty"))
            }
            if !trimmed.contains("{script}") {
                throw terminalError(code: 11, message: String(localized: "terminalCustomCommandMissingPlaceholder"))
            }
        case .systemDefault:
            if scriptPath.isEmpty { throw terminalError(code: 12, message: String(localized: "containerShellOpenFailed")) }
        default:
            if appURL(for: cfg.app) == nil {
                let name = cfg.app.displayName
                throw terminalError(
                    code: 13,
                    message: String(format: String(localized: "terminalAppNotInstalled %@"), name)
                )
            }
        }
    }

    /// Launches the chosen terminal with the given script. Throws on validation
    /// or launch failure. `openInBackground` is `true` for the regular shell
    /// button; tests use a "no-op" path (see `ContainerShellLauncher`).
    static func launch(cfg: TerminalConfig, scriptURL: URL) throws {
        try validate(cfg: cfg, scriptPath: scriptURL.path)
        switch cfg.app {
        case .systemDefault:
            let opened = NSWorkspace.shared.open(scriptURL)
            if !opened {
                throw terminalError(code: 20, message: String(localized: "containerShellOpenFailed"))
            }
        case .terminal, .iterm2, .warp:
            try openViaBundle(cfg: cfg, scriptURL: scriptURL)
        case .ghostty, .alacritty, .kitty, .wezterm, .hyper:
            try openViaBinary(cfg: cfg, scriptURL: scriptURL)
        case .custom:
            try openViaCustomCommand(cfg: cfg, scriptURL: scriptURL)
        }
    }

    /// Resolves the custom command by substituting `{script}` with the script path.
    /// Public for tests.
    static func resolvedCommand(cfg: TerminalConfig, scriptPath: String) -> String {
        cfg.customCommand.replacingOccurrences(of: "{script}", with: scriptPath)
    }

    // MARK: - Private

    private static func openViaBundle(cfg: TerminalConfig, scriptURL: URL) throws {
        guard let bundleId = cfg.app.bundleIdentifier,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
              let appName = appURL.deletingPathExtension().lastPathComponent.isEmpty
                ? .some(bundleId)
                : .some(appURL.deletingPathExtension().lastPathComponent)
        else {
            let name = cfg.app.displayName
            throw terminalError(
                code: 30,
                message: String(format: String(localized: "terminalAppNotInstalled %@"), name)
            )
        }
        // Use `/usr/bin/open -a <AppName> <script>` — this is the cross-version
        // way to target a specific app to open a file. NSWorkspace's bundle-targeted
        // open is async-only on macOS 26.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appName, scriptURL.path]
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                Log.details.error("TerminalLauncher /usr/bin/open -a \(appName, privacy: .public) exited \(process.terminationStatus, privacy: .public)")
                throw terminalError(code: 31, message: String(localized: "containerShellOpenFailed"))
            }
        } catch let error as NSError where error.domain == "TerminalLauncher" {
            throw error
        } catch {
            Log.details.error("TerminalLauncher /usr/bin/open -a failed for \(cfg.app.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw terminalError(code: 32, message: String(localized: "containerShellOpenFailed"))
        }
    }

    private static func openViaBinary(cfg: TerminalConfig, scriptURL: URL) throws {
        guard let appURL = appURL(for: cfg.app) else {
            let name = cfg.app.displayName
            throw terminalError(
                code: 40,
                message: String(format: String(localized: "terminalAppNotInstalled %@"), name)
            )
        }
        let binaryName = cfg.app.binaryName
        let binaryURL = appURL.appendingPathComponent("Contents/MacOS").appendingPathComponent(binaryName)
        guard FileManager.default.isExecutableFile(atPath: binaryURL.path) else {
            throw terminalError(code: 41, message: String(localized: "containerShellOpenFailed"))
        }
        let process = Process()
        process.executableURL = binaryURL
        process.arguments = [cfg.app.cliArgument, scriptURL.path]
        do {
            try process.run()
        } catch {
            Log.details.error("TerminalLauncher process.run failed for \(cfg.app.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw terminalError(code: 42, message: String(localized: "containerShellOpenFailed"))
        }
    }

    private static func openViaCustomCommand(cfg: TerminalConfig, scriptURL: URL) throws {
        let command = resolvedCommand(cfg: cfg, scriptPath: scriptURL.path)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        do {
            try process.run()
        } catch {
            Log.details.error("TerminalLauncher custom command failed: \(error.localizedDescription, privacy: .public)")
            throw terminalError(code: 50, message: String(localized: "containerShellOpenFailed"))
        }
    }

    private static func terminalError(code: Int, message: String) -> NSError {
        NSError(domain: "TerminalLauncher", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private extension TerminalApp {
    /// Executable name inside `Contents/MacOS` for CLI-driven terminals.
    var binaryName: String {
        switch self {
        case .ghostty: return "ghostty"
        case .alacritty: return "alacritty"
        case .kitty: return "kitty"
        case .wezterm: return "wezterm"
        case .hyper: return "Hyper"
        default: return ""
        }
    }

    /// Argument flag used to pass the script path. `-e` is the standard, except
    /// kitty which uses `+`. Hyper accepts a URL as a positional arg with no flag.
    var cliArgument: String {
        switch self {
        case .kitty: return "+"
        case .hyper: return ""
        default: return "-e"
        }
    }
}
