//
//  AsyncUtilities.swift
//  Crane
//

import Foundation

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
