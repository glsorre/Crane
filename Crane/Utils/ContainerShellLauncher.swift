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

    /// Opens the user’s default terminal application with an interactive `container exec` shell (via a `.command` script).
    static func openInteractiveShell(containerID: String) throws {
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

        guard let cliURL = containerCLIExecutableURL() else {
            throw NSError(
                domain: "ContainerShellLauncher",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "containerShellCLINotFound")]
            )
        }

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("crane-shell-\(UUID().uuidString).command")

        let script = """
        #!/bin/bash
        exec \(bashSingleQuoted(cliURL.path)) exec --interactive --tty \(bashSingleQuoted(trimmed)) /bin/sh

        """

        try script.data(using: .utf8)?.write(to: scriptURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: scriptURL.path)

        let opened = NSWorkspace.shared.open(scriptURL)
        guard opened else {
            throw NSError(
                domain: "ContainerShellLauncher",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "containerShellOpenFailed")]
            )
        }
    }

    /// Wraps a string in single quotes for a bash word, escaping embedded single quotes.
    private static func bashSingleQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
