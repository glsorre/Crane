import ContainerAPIClient
import ContainerResource
import Containerization
import ContainerizationError
import XCTest

@testable import Crane

class CraneTestBase: XCTestCase {
    static let testPrefix = "crane-test-"

    let containerClient = ContainerClient()
    let networkClient = NetworkClient()
    @MainActor var stores: CraneStores!

    func uniqueName() -> String {
        Self.testPrefix + UUID().uuidString.prefix(8).lowercased()
    }

    override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            stores = CraneStores()
        }
        // Fail fast if apiserver is not reachable
        _ = try await containerClient.list()
    }

    override func tearDown() async throws {
        // Sweep test containers
        let containers = try await containerClient.list()
        for container in containers where container.id.hasPrefix(Self.testPrefix) {
            try? await containerClient.stop(id: container.id)
            try? await containerClient.delete(id: container.id)
        }

        // Sweep test networks
        let networks = try await networkClient.list()
        for network in networks where network.id.hasPrefix(Self.testPrefix) {
            try? await networkClient.delete(id: network.id)
        }

        // Sweep test volumes
        let volumes = try await ClientVolume.list()
        for volume in volumes where volume.name.hasPrefix(Self.testPrefix) {
            try? await ClientVolume.delete(name: volume.name)
        }

        try await super.tearDown()
    }

    func defaultKernel() async throws -> Kernel {
        do {
            return try await ClientKernel.getDefaultKernel(for: .current)
        } catch let error as ContainerizationError where error.isCode(.notFound) {
            throw XCTSkip("Default container kernel is not configured. Run `container system kernel set --recommended`.")
        }
    }

    func waitForCondition(
        timeout: TimeInterval = 10,
        interval: TimeInterval = 0.5,
        _ condition: @escaping () async throws -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if try await condition() { return }
            try await Task.sleep(for: .milliseconds(Int(interval * 1000)))
        }
        XCTFail("Condition not met within \(timeout)s")
    }
}
