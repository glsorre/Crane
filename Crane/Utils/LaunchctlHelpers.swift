//
//  LaunchctlHelpers.swift
//  Crane
//

import Foundation

struct LaunchctlState {
    let loaded: Bool
    let rawOutput: String?
}

/// Runs `launchctl print <domain>/<label>` and returns load state plus raw output.
/// Raw output is truncated to the last 2 KB so it stays paste-friendly in diagnostic UI.
func launchctlState(label: String, domain: String) -> LaunchctlState {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    process.arguments = ["print", "\(domain)/\(label)"]
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let truncated: String? = {
            guard !trimmed.isEmpty else { return nil }
            let maxBytes = 2048
            if trimmed.utf8.count <= maxBytes { return trimmed }
            let suffixStart = trimmed.index(trimmed.endIndex, offsetBy: -maxBytes)
            return "…\(trimmed[suffixStart...])"
        }()
        return LaunchctlState(
            loaded: process.terminationStatus == 0 && !trimmed.isEmpty,
            rawOutput: truncated
        )
    } catch {
        return LaunchctlState(loaded: false, rawOutput: error.localizedDescription)
    }
}

func isServiceLoaded(label: String, domain: String) -> Bool {
    launchctlState(label: label, domain: domain).loaded
}
