//
//  ProcessExecution.swift
//  Crane
//

import Foundation
import os

/// Runs a Process to completion and returns merged stdout+stderr. Drains the pipe concurrently via
/// `readabilityHandler` and resumes from `terminationHandler` so the caller never blocks on `waitUntilExit`.
func runProcessCollectingOutput(
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
            let remaining = (try? pipe.fileHandleForReading.readToEnd())
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
