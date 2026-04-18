@testable import Crane
import ContainerAPIClient
import ContainerResource
import Containerization
import ContainerizationError
import XCTest

class CraneTestBase: XCTestCase {
    static let testPrefix = "crane-test-"

    let containerClient = ContainerClient()

    func uniqueName() -> String {
        Self.testPrefix + UUID().uuidString.prefix(8).lowercased()
    }

    override func setUp() async throws {
        try await super.setUp()
        // Stop any polling that singleton inits may have started
        ContainersStore.shared.stop()
        ImagesStore.shared.stop()
        NetworksStore.shared.stop()
        VolumesStore.shared.stop()
        // Fail fast if apiserver is not reachable
        _ = try await containerClient.list()
    }

    override func tearDown() async throws {
        // Sweep test containers
        let containers = try await containerClient.list()
        for c in containers where c.id.hasPrefix(Self.testPrefix) {
            try? await containerClient.stop(id: c.id)
            try? await containerClient.delete(id: c.id)
        }

        // Sweep test networks
        let networks = try await ClientNetwork.list()
        for n in networks where n.id.hasPrefix(Self.testPrefix) {
            try? await ClientNetwork.delete(id: n.id)
        }

        // Sweep test volumes
        let volumes = try await ClientVolume.list()
        for v in volumes where v.name.hasPrefix(Self.testPrefix) {
            try? await ClientVolume.delete(name: v.name)
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
