@testable import Crane
import ContainerAPIClient
import ContainerResource
import ContainerizationOCI
import XCTest

final class ContainersStoreTests: CraneTestBase {
    func testCollect() async throws {
        try await ContainersStore.shared.collect()
    }

    func testContainerLifecycle() async throws {
        // Ensure alpine is available
        let reference = "docker.io/library/alpine:latest"
        _ = try await ClientImage.fetch(reference: reference)

        let images = try await ClientImage.list()
        let alpine = try XCTUnwrap(images.first { $0.reference.contains("alpine") })

        let containerID = uniqueName()
        let process = ProcessConfiguration(executable: "/bin/sh", arguments: ["-c", "sleep 30"], environment: [])
        var config = ContainerConfiguration(
            id: containerID,
            image: alpine.description,
            process: process
        )
        config.networks = []

        let options = ContainerCreateOptions(autoRemove: true)
        let created = try await ClientContainer.create(
            configuration: config,
            options: options,
            kernel: ClientKernel.getDefaultKernel(for: .current)
        )

        // Start container
        let io = try ProcessIO.create(tty: false, interactive: false, detach: true)
        defer { _ = try? io.close() }
        let proc = try await created.bootstrap(stdio: io.stdio)
        try await proc.start()

        // Verify it appears in container list
        try await waitForCondition {
            let list = try await ClientContainer.list()
            return list.contains { $0.id == containerID }
        }

        // Stop
        try await created.stop()

        // Verify it's gone (autoRemove)
        try await waitForCondition {
            let list = try await ClientContainer.list()
            return !list.contains { $0.id == containerID }
        }
    }
}
