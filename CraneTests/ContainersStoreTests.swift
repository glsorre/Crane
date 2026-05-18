@testable import Crane
import ContainerAPIClient
import ContainerResource
import ContainerizationOCI
import XCTest

final class ContainersStoreTests: CraneTestBase {
    func testCollect() async throws {
        let containers = await MainActor.run { stores.containers }
        try await containers.collect()
    }

    func testContainerLifecycle() async throws {
        // Ensure alpine is available
        let reference = "docker.io/library/alpine:latest"
        _ = try await ClientImage.fetch(reference: reference)

        let images = try await ClientImage.list()
        let alpine = try XCTUnwrap(
            images.first { $0.reference.contains("library/alpine") || $0.reference.contains("alpine:latest") }
                ?? images.first { $0.reference.contains("alpine") }
        )

        let containerID = uniqueName()
        let process = ProcessConfiguration(executable: "/bin/sh", arguments: ["-c", "sleep 30"], environment: [])
        var config = ContainerConfiguration(
            id: containerID,
            image: alpine.description,
            process: process
        )
        config.networks = []

        let options = ContainerCreateOptions(autoRemove: true)
        try await containerClient.create(
            configuration: config,
            options: options,
            kernel: try await defaultKernel()
        )

        // Wait for the created container to become visible before bootstrapping it.
        try await waitForCondition(timeout: 30) {
            let list = try await self.containerClient.list()
            return list.contains { $0.id == containerID }
        }

        // Let the apiserver finish registering the container (avoids bootstrap notFound under load).
        try await Task.sleep(for: .milliseconds(400))

        // Start container
        let io = try ProcessIO.create(tty: false, interactive: false, detach: true)
        defer { _ = try? io.close() }

        let proc: ClientProcess = try await {
            let deadline = Date().addingTimeInterval(30)
            while true {
                do {
                    return try await self.containerClient.bootstrap(id: containerID, stdio: io.stdio)
                } catch {
                    if Date() >= deadline {
                        throw error
                    }
                    try await Task.sleep(for: .milliseconds(250))
                }
            }
        }()

        try await proc.start()

        // Verify it appears in container list
        try await waitForCondition {
            let list = try await self.containerClient.list()
            return list.contains { $0.id == containerID }
        }

        // Stop
        try await containerClient.stop(id: containerID)

        // Verify it's gone (autoRemove)
        try await waitForCondition(timeout: 45) {
            let list = try await self.containerClient.list()
            return !list.contains { $0.id == containerID }
        }
    }
}
