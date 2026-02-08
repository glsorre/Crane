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

func startContainerService() async -> Bool {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let plistURL = appSupport.appendingPathComponent("com.apple.container/apiserver/apiserver.plist")

    guard FileManager.default.fileExists(atPath: plistURL.path) else {
        logger.warning("Plist not found at \(plistURL.path) — user must run `container system start` once")
        return false
    }

    // Re-write the plist atomically to clear stale launchd state after bootout
    do {
        let data = try Data(contentsOf: plistURL)
        try data.write(to: plistURL, options: .atomic)
        logger.info("Re-wrote plist to refresh file state")
    } catch {
        logger.error("Failed to re-write plist: \(error.localizedDescription)")
        // Continue anyway — bootstrap might still work
    }

    // Use ContainerPlugin's ServiceManager (same API used by `container system start`)
    do {
        try ServiceManager.register(plistPath: plistURL.path)
        logger.info("ServiceManager.register() succeeded")
        return true
    } catch {
        logger.error("ServiceManager.register() failed: \(error.localizedDescription)")
        return false
    }
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
