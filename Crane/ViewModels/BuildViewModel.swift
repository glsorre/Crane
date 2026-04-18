//
//  BuildViewModel.swift
//  Crane
//

import ContainerAPIClient
import ContainerBuild
import ContainerImagesServiceClient
import ContainerResource
import ContainerizationOCI
import Foundation
import NIO
import Observation

enum BuildStatus: Equatable {
    case idle
    case startingBuilder
    case building
    case unpacking
    case success
    case failed(String)

    var isBuilding: Bool {
        switch self {
        case .startingBuilder, .building, .unpacking:
            return true
        default:
            return false
        }
    }
}

@Observable
class BuildViewModel {
    private let containerClient = ContainerClient()

    var status: BuildStatus = .idle

    func build(tag: String, dockerfileContent: String) async {
        status = .startingBuilder

        do {
            // 1. Ensure builder running
            let container: ContainerSnapshot
            do {
                container = try await containerClient.get(id: "buildkit")
            } catch {
                status = .failed("BuildKit container not found. Run 'container builder start' in Terminal.")
                return
            }

            var fh: FileHandle
            do {
                fh = try await containerClient.dial(id: container.id, port: 8088)
            } catch {
                // Container exists but might be stopped — try to start it
                do {
                    let io = try ProcessIO.create(tty: true, interactive: false, detach: true)
                    defer { _ = try? io.close() }
                    let process = try await containerClient.bootstrap(id: container.id, stdio: io.stdio)
                    try await process.start()
                    try await Task.sleep(for: .seconds(5))
                    fh = try await containerClient.dial(id: container.id, port: 8088)
                } catch {
                    status = .failed("Failed to start BuildKit: \(error.localizedDescription)")
                    return
                }
            }

            // 2. Create Builder
            let threadGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
            let builder = try Builder(socket: fh, group: threadGroup)
            let _ = try await builder.info()

            // 3. Write temp Dockerfile
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("crane-build-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let dockerfilePath = tempDir.appendingPathComponent("Dockerfile")
            try dockerfileContent.write(to: dockerfilePath, atomically: true, encoding: .utf8)
            let dockerfileData = try Data(contentsOf: dockerfilePath)

            // 4. Get export path
            let systemHealth = try await ClientHealthCheck.ping(timeout: .seconds(10))
            let exportPath = systemHealth.appRoot.appendingPathComponent("builder")
            let buildID = UUID().uuidString
            let tempExportURL = exportPath.appendingPathComponent(buildID)
            try FileManager.default.createDirectory(at: tempExportURL, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempExportURL) }

            // 5. Normalize tag
            let normalizedTag = try ClientImage.normalizeReference(tag)

            // 6. Configure build
            var export = try Builder.BuildExport(from: "type=oci")
            export.destination = tempExportURL.appendingPathComponent("out.tar")

            let platform = try Platform(from: "linux/arm64")

            let config = Builder.BuildConfig(
                buildID: buildID,
                contentStore: RemoteContentStoreClient(),
                buildArgs: [],
                secrets: [:],
                contextDir: tempDir.path,
                dockerfile: dockerfileData,
                hiddenDockerDir: nil,
                labels: [],
                noCache: false,
                platforms: [platform],
                terminal: nil,
                tags: [normalizedTag],
                target: "",
                quiet: true,
                exports: [export],
                cacheIn: [],
                cacheOut: [],
                pull: false
            )

            // 7. Build
            status = .building
            try await builder.build(config)

            // 8. Unpack
            status = .unpacking
            guard let dest = export.destination else {
                throw NSError(domain: "Build", code: 1, userInfo: [NSLocalizedDescriptionKey: "Export destination missing"])
            }
            let result = try await ClientImage.load(from: dest.path, force: false)
            for image in result.images {
                try await image.unpack(platform: nil)
                _ = try await image.tag(new: normalizedTag)
            }

            // 9. Refresh
            try? await ImagesStore.shared.collect()

            status = .success
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
