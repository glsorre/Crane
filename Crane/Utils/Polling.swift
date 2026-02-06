import Foundation
import os.log

func startPolling(interval: @escaping () -> Int, work: @escaping () async throws -> Void) -> Task<Void, Never> {
    Task {
        while !Task.isCancelled {
            do { try await work() }
            catch { Logger.crane.warning("Polling error: \(error.localizedDescription)") }
            try? await Task.sleep(for: .seconds(max(interval(), 1)))
        }
    }
}
