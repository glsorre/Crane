//
//  helpers.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 13/11/25.
//

import ContainerPlugin
import Foundation
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

private func findContainerCLI() -> URL? {
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

private func startContainerServiceViaCLI(cliURL: URL) async -> Bool {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = cliURL
    process.arguments = ["system", "start", "--disable-kernel-install"]
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        logger.info("Starting container services via CLI at \(cliURL.path, privacy: .public)")
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if output.isEmpty {
                logger.error("`container system start --disable-kernel-install` failed with status \(process.terminationStatus)")
            } else {
                logger.error("`container system start --disable-kernel-install` failed with status \(process.terminationStatus): \(output, privacy: .public)")
            }
            return false
        }

        logger.info("`container system start --disable-kernel-install` succeeded")
        return true
    } catch {
        logger.error("Failed to run container CLI at \(cliURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        return false
    }
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
    if let cliURL = findContainerCLI() {
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
