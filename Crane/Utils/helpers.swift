//
//  helpers.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 13/11/25.
//

import ContainerPlugin
import Foundation
import os
import os.log

private let logger = Logger(subsystem: "me.rightright.RightCrane", category: "ServiceHelper")
private let containerCLIName = "container"

func isServiceLoaded(label: String, domain: String) -> Bool {
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
        if process.terminationStatus == 0 && !output.isEmpty {
            return true
        } else {
            return false
        }
    } catch {
        return false
    }
}

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
private func runContainerCLI(cliURL: URL, arguments: [String]) async -> (status: Int32, output: String) {
    await runProcessCollectingOutput(
        executableURL: cliURL,
        arguments: arguments,
        environment: processEnvironmentWithExtendedPATH()
    )
}

/// Runs a Process to completion and returns merged stdout+stderr. Drains the pipe concurrently via
/// `readabilityHandler` and resumes from `terminationHandler` so the caller never blocks on `waitUntilExit`.
private func runProcessCollectingOutput(
    executableURL: URL,
    arguments: [String],
    environment: [String: String]? = nil
) async -> (status: Int32, output: String) {
    await withCheckedContinuation { (continuation: CheckedContinuation<(status: Int32, output: String), Never>) in
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        if let environment { process.environment = environment }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = pipe
        process.standardError = pipe

        let outputBox = OSAllocatedUnfairLock(initialState: Data())
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
            } else {
                outputBox.withLock { $0.append(chunk) }
            }
        }

        process.terminationHandler = { proc in
            pipe.fileHandleForReading.readabilityHandler = nil
            // Drain any bytes still buffered after EOF.
            let remaining = (try? pipe.fileHandleForReading.readToEnd()) ?? nil
            let data = outputBox.withLock { box -> Data in
                if let remaining { box.append(remaining) }
                return box
            }
            let output = String(data: data, encoding: .utf8) ?? ""
            continuation.resume(returning: (proc.terminationStatus, output.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        do {
            try process.run()
        } catch {
            process.terminationHandler = nil
            pipe.fileHandleForReading.readabilityHandler = nil
            continuation.resume(returning: (-1, error.localizedDescription))
        }
    }
}

/// Outcome of trying to start the BuildKit builder via the `container` CLI after `get(buildkit)` failed.
enum StartBuilderContainerOutcome: Sendable {
    /// `container builder start` completed successfully.
    case builderReady
    /// CLI missing or `builder start` failed for a reason other than missing Linux VM Rosetta.
    case failed
    /// First `builder start` failed with “Rosetta is not installed”; the user should choose to install or continue without Rosetta.
    case needsRosettaChoice
}

/// Runs `container builder start` once (no `build.rosetta` changes). Used after the user installs Linux VM Rosetta.
func runContainerBuilderStartOnly() async -> Bool {
    guard let cliURL = containerCLIExecutableURL() else {
        logger.warning("`container` CLI not found; cannot start BuildKit builder")
        return false
    }
    logger.info("Running `container builder start` at \(cliURL.path, privacy: .public)")
    let (status, output) = await runContainerCLI(cliURL: cliURL, arguments: ["builder", "start"])
    guard status == 0 else {
        logger.error("`container builder start` failed with status \(status): \(output, privacy: .public)")
        return false
    }
    logger.info("`container builder start` succeeded")
    return true
}

/// Sets `build.rosetta` to false and runs `container builder start` (QEMU path). Used when the user opts out of Rosetta.
func startBuilderContainerWithRosettaDisabledViaCLI() async -> Bool {
    guard let cliURL = containerCLIExecutableURL() else {
        logger.warning("`container` CLI not found; cannot start BuildKit builder")
        return false
    }
    return await startBuilderViaCLIWithRosettaDisabled(cliURL: cliURL)
}

/// First attempt to start the builder: runs `container builder start` only. Does not disable `build.rosetta`.
func startBuilderContainerViaCLI() async -> StartBuilderContainerOutcome {
    guard let cliURL = containerCLIExecutableURL() else {
        logger.warning("`container` CLI not found; cannot start BuildKit builder")
        return .failed
    }
    logger.info("Starting BuildKit builder via CLI at \(cliURL.path, privacy: .public)")
    let (status, output) = await runContainerCLI(cliURL: cliURL, arguments: ["builder", "start"])
    if status == 0 {
        logger.info("`container builder start` succeeded")
        return .builderReady
    }
    if output.contains("Rosetta is not installed") {
        logger.info("BuildKit bootstrap requires Linux VM Rosetta or user choice to disable build.rosetta")
        return .needsRosettaChoice
    }
    logger.error("`container builder start` failed with status \(status): \(output, privacy: .public)")
    return .failed
}

private func startBuilderViaCLIWithRosettaDisabled(cliURL: URL) async -> Bool {
    logger.info("Disabling build.rosetta and starting BuildKit at \(cliURL.path, privacy: .public)")
    let (propStatus, propOut) = await runContainerCLI(
        cliURL: cliURL,
        arguments: ["system", "property", "set", "build.rosetta", "false"]
    )
    if propStatus != 0 {
        logger.warning("`container system property set build.rosetta false` failed with status \(propStatus): \(propOut, privacy: .public)")
    } else {
        logger.info("Set build.rosetta to false; retrying `container builder start`")
    }
    let (status, output) = await runContainerCLI(cliURL: cliURL, arguments: ["builder", "start"])
    guard status == 0 else {
        logger.error("`container builder start` failed with status \(status): \(output, privacy: .public)")
        return false
    }
    logger.info("`container builder start` succeeded")
    return true
}

private func startContainerServiceViaCLI(cliURL: URL) async -> Bool {
    logger.info("Starting container services via CLI at \(cliURL.path, privacy: .public)")
    let (status, output) = await runProcessCollectingOutput(
        executableURL: cliURL,
        arguments: ["system", "start", "--disable-kernel-install"]
    )
    guard status == 0 else {
        if output.isEmpty {
            logger.error("`container system start --disable-kernel-install` failed with status \(status)")
        } else {
            logger.error("`container system start --disable-kernel-install` failed with status \(status): \(output, privacy: .public)")
        }
        return false
    }
    logger.info("`container system start --disable-kernel-install` succeeded")
    return true
}

private func startContainerServiceViaPlistBootstrap() async -> Bool {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let plistURL = appSupport.appendingPathComponent("com.apple.container/apiserver/apiserver.plist")

    guard FileManager.default.fileExists(atPath: plistURL.path) else {
        logger.warning("Plist not found at \(plistURL.path) — user must run `container system start` once")
        return false
    }

    do {
        let data = try Data(contentsOf: plistURL)
        try data.write(to: plistURL, options: .atomic)
        logger.info("Re-wrote plist to refresh file state")
    } catch {
        logger.error("Failed to re-write plist: \(error.localizedDescription)")
    }

    do {
        try ServiceManager.register(plistPath: plistURL.path)
        logger.info("ServiceManager.register() succeeded")
        return true
    } catch {
        logger.error("ServiceManager.register() failed: \(error.localizedDescription)")
        return false
    }
}

func startContainerService() async -> Bool {
    if let cliURL = containerCLIExecutableURL() {
        return await startContainerServiceViaCLI(cliURL: cliURL)
    }

    logger.warning("`container` CLI not found; falling back to launchd plist bootstrap")
    return await startContainerServiceViaPlistBootstrap()
}

func withTimeout(action: @escaping () async throws -> Void, timeout: Int = 10) async throws {
    let task = Task {
        try await action()
    }
    
    let timeoutTask = Task {
        try await Task.sleep(for: .seconds(timeout))
        task.cancel()
    }
    
    try await task.value
    timeoutTask.cancel()
}
