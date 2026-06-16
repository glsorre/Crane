//
//  ContainerShellLauncher.swift
//  Crane
//

import AppKit
import Foundation

enum ContainerShellLauncher {
    private static let allowedContainerIDCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._"
    )

    /// Opens the user’s chosen terminal application with an interactive `container exec` shell.
    /// The terminal selection is read from `UserDefaults` via `TerminalConfig.load()`.
    /// The default value of `config:` is `.load()`; in tests pass `.default` to keep things hermetic.
    static func openInteractiveShell(containerID: String, config: TerminalConfig = .load()) throws {
        try validateContainerID(containerID)
        guard let cliURL = containerCLIExecutableURL() else {
            throw NSError(
                domain: "ContainerShellLauncher",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "containerShellCLINotFound")]
            )
        }
        let scriptURL = try makeExecutableScript(containerID: containerID, cliURL: cliURL)
        var launched = false
        defer {
            if !launched {
                try? FileManager.default.removeItem(at: scriptURL)
            }
        }
        try TerminalLauncher.launch(cfg: config, scriptURL: scriptURL)
        launched = true

        // `NSWorkspace.open` returns before the terminal may finish reading the script; remove after a short delay.
        let urlToRemove = scriptURL
        Task.detached(priority: .utility) {
            try? await Task.sleep(for: .seconds(5))
            try? FileManager.default.removeItem(at: urlToRemove)
        }
    }

    /// Validates the container id format. Throws on empty or invalid input.
    static func validateContainerID(_ containerID: String) throws {
        let trimmed = containerID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(
                domain: "ContainerShellLauncher",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "containerShellInvalidID")]
            )
        }
        guard trimmed.unicodeScalars.allSatisfy({ allowedContainerIDCharacters.contains($0) }) else {
            throw NSError(
                domain: "ContainerShellLauncher",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "containerShellInvalidID")]
            )
        }
    }

    /// Builds the temp `.command` script for a given container id and CLI URL.
    /// Public so tests / future callers can inspect the produced script path.
    static func makeExecutableScript(containerID: String, cliURL: URL) throws -> URL {
        let trimmed = containerID.trimmingCharacters(in: .whitespacesAndNewlines)
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("crane-shell-\(UUID().uuidString).command")
        let script = """
            #!/bin/bash
            exec \(bashSingleQuoted(cliURL.path)) exec --interactive --tty \(bashSingleQuoted(trimmed)) /bin/sh

            """
        try script.data(using: .utf8)?.write(to: scriptURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: scriptURL.path)
        return scriptURL
    }

    /// Wraps a string in single quotes for a bash word, escaping embedded single quotes.
    static func bashSingleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
