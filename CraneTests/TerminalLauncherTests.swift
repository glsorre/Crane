import XCTest

@testable import Crane

final class TerminalLauncherTests: XCTestCase {
    func testAllCasesHaveBundleOrPath() {
        for app in TerminalApp.allCases {
            if app == .custom { continue }
            if app == .systemDefault { continue }  // system default opens via the OS, not a specific bundle
            XCTAssertNotNil(app.bundleIdentifier, "Missing bundle id for \(app)")
        }
    }

    func testRawValueRoundTrip() {
        for app in TerminalApp.allCases {
            XCTAssertEqual(TerminalApp(rawValue: app.rawValue), app)
        }
        XCTAssertNil(TerminalApp(rawValue: "wezterm-alpha"))
    }

    func testConfigLoadDefault() {
        // Isolate UserDefaults so the test is hermetic.
        let suite = "crane-terminal-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let cfg = TerminalConfig.load(from: defaults)
        XCTAssertEqual(cfg.app, .systemDefault)
        XCTAssertEqual(cfg.customCommand, "open -a Terminal {script}")
    }

    func testConfigLoadReadsStoredValues() {
        let suite = "crane-terminal-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(TerminalApp.ghostty.rawValue, forKey: "terminalApp")
        defaults.set("/opt/homebrew/bin/ghostty -e {script}", forKey: "terminalCustomCommand")

        let cfg = TerminalConfig.load(from: defaults)
        XCTAssertEqual(cfg.app, .ghostty)
        XCTAssertEqual(cfg.customCommand, "/opt/homebrew/bin/ghostty -e {script}")
    }

    func testConfigLoadUnknownAppFallsBackToDefault() {
        let suite = "crane-terminal-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("nonexistent-terminal", forKey: "terminalApp")

        let cfg = TerminalConfig.load(from: defaults)
        XCTAssertEqual(cfg.app, .systemDefault)
    }

    func testCustomCommandSubstitution() {
        let cfg = TerminalConfig(app: .custom, customCommand: "echo {script} && true")
        let resolved = TerminalLauncher.resolvedCommand(cfg: cfg, scriptPath: "/tmp/crane-x.command")
        XCTAssertEqual(resolved, "echo /tmp/crane-x.command && true")
    }

    func testEmptyCustomCommandRejects() {
        var cfg = TerminalConfig.default
        cfg.app = .custom
        cfg.customCommand = ""
        XCTAssertThrowsError(try TerminalLauncher.validate(cfg: cfg, scriptPath: "/tmp/x.command"))
    }

    func testMissingPlaceholderRejects() {
        var cfg = TerminalConfig.default
        cfg.app = .custom
        cfg.customCommand = "open -a Terminal"
        XCTAssertThrowsError(try TerminalLauncher.validate(cfg: cfg, scriptPath: "/tmp/x.command"))
    }

    func testUsesCLIInvocationFlag() {
        XCTAssertTrue(TerminalApp.ghostty.usesCLIInvocation)
        XCTAssertTrue(TerminalApp.alacritty.usesCLIInvocation)
        XCTAssertTrue(TerminalApp.kitty.usesCLIInvocation)
        XCTAssertTrue(TerminalApp.wezterm.usesCLIInvocation)
        XCTAssertTrue(TerminalApp.hyper.usesCLIInvocation)
        XCTAssertFalse(TerminalApp.terminal.usesCLIInvocation)
        XCTAssertFalse(TerminalApp.iterm2.usesCLIInvocation)
        XCTAssertFalse(TerminalApp.warp.usesCLIInvocation)
        XCTAssertFalse(TerminalApp.systemDefault.usesCLIInvocation)
    }
}
