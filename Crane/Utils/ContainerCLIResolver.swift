//
//  ContainerCLIResolver.swift
//  Crane
//

import Foundation

private let containerCLIName = "container"

/// Resolves the `container` CLI executable using `CONTAINER_INSTALL_ROOT`, `PATH`, then common install locations.
func containerCLIExecutableURL() -> URL? {
    let fileManager = FileManager.default
    var seen = Set<String>()
    var candidateDirectories: [String] = []

    if let installRoot = ProcessInfo.processInfo.environment["CONTAINER_INSTALL_ROOT"], !installRoot.isEmpty {
        candidateDirectories.append(URL(fileURLWithPath: installRoot).appendingPathComponent("bin").path)
    }

    if let path = ProcessInfo.processInfo.environment["PATH"], !path.isEmpty {
        candidateDirectories.append(contentsOf: path.split(separator: ":").map(String.init))
    }

    candidateDirectories.append(contentsOf: [
        "/opt/homebrew/bin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
    ])

    for directory in candidateDirectories {
        let cliURL = URL(fileURLWithPath: directory).appendingPathComponent(containerCLIName)
        let cliPath = cliURL.path
        guard seen.insert(cliPath).inserted else { continue }
        guard fileManager.isExecutableFile(atPath: cliPath) else { continue }
        return cliURL.resolvingSymlinksInPath()
    }

    return nil
}

/// GUI apps often inherit a minimal `PATH`; child processes spawned by the CLI may need Homebrew/system paths.
private func processEnvironmentWithExtendedPATH() -> [String: String] {
    var env = ProcessInfo.processInfo.environment
    let prefix = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    if let existing = env["PATH"], !existing.isEmpty {
        if !existing.contains("/opt/homebrew/bin") || !existing.contains("/usr/local/bin") {
            env["PATH"] = "\(prefix):\(existing)"
        }
    } else {
        env["PATH"] = prefix
    }
    env["NO_COLOR"] = "1"
    return env
}

/// Runs the `container` CLI with stdout+stderr merged; same environment as other Crane-driven CLI calls.
/// Async: suspends until the subprocess exits without blocking the calling thread (safe to call from MainActor).
func runContainerCLI(cliURL: URL, arguments: [String]) async -> (status: Int32, output: String) {
    await runProcessCollectingOutput(
        executableURL: cliURL,
        arguments: arguments,
        environment: processEnvironmentWithExtendedPATH()
    )
}
