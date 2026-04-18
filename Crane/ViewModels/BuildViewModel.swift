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

enum ImageBuildSource: Sendable {
    /// Isolated temp directory containing only the pasted Dockerfile.
    case pastedDockerfile(String)
    /// Host directory used as BuildKit context; `.dockerignore` at the context root is applied by BuildKit when supported by the runtime.
    case localContext(contextDirectory: URL, dockerfileRelativePath: String)
}

extension ImageBuildSource {
    /// Resolves the Dockerfile URL inside the context, or nil if the path is invalid or escapes the context folder.
    static func resolvedDockerfileURL(contextDirectory: URL, dockerfileRelativePath: String) -> URL? {
        try? BuildViewModel.resolveDockerfileURL(
            context: contextDirectory.standardizedFileURL,
            relativePath: dockerfileRelativePath
        )
    }
}

@Observable
class BuildViewModel {
    private let containerClient = ContainerClient()

    var status: BuildStatus = .idle

    /// Builds from pasted Dockerfile text (legacy single-field flow).
    func build(tag: String, dockerfileContent: String) async {
        await build(tag: tag, source: .pastedDockerfile(dockerfileContent))
    }

    func build(tag: String, source: ImageBuildSource) async {
        status = .startingBuilder

        do {
            let (contextDirPath, dockerfileData, contextDirToDelete) = try prepareBuildPaths(source: source)
            defer {
                if let dir = contextDirToDelete {
                    try? FileManager.default.removeItem(at: dir)
                }
            }

            try await runBuildKitPipeline(tag: tag, contextDirPath: contextDirPath, dockerfileData: dockerfileData)
            status = .success
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Resolves context directory and Dockerfile bytes. Returns a temp directory URL to delete after the build when non-nil.
    private func prepareBuildPaths(source: ImageBuildSource) throws -> (contextDirPath: String, dockerfileData: Data, contextDirToDelete: URL?) {
        switch source {
        case .pastedDockerfile(let dockerfileContent):
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("crane-build-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let dockerfilePath = tempDir.appendingPathComponent("Dockerfile")
            try dockerfileContent.write(to: dockerfilePath, atomically: true, encoding: .utf8)
            let dockerfileData = try Data(contentsOf: dockerfilePath)
            return (tempDir.path, dockerfileData, tempDir)

        case .localContext(let contextDirectory, let dockerfileRelativePath):
            // BuildKit receives the host context path as-is; `.dockerignore` at the context root is honored when the runtime supports it. If builds fail for paths outside a known mount, a staged copy (respecting `.dockerignore`) could be added here.
            var isDir: ObjCBool = false
            let standardizedContext = contextDirectory.standardizedFileURL
            guard FileManager.default.fileExists(atPath: standardizedContext.path, isDirectory: &isDir),
                  isDir.boolValue
            else {
                throw NSError(
                    domain: "Build",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "imageBuildContextNotDirectory")]
                )
            }

            let dockerfileURL = try Self.resolveDockerfileURL(
                context: standardizedContext,
                relativePath: dockerfileRelativePath
            )
            guard FileManager.default.fileExists(atPath: dockerfileURL.path) else {
                throw NSError(
                    domain: "Build",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "imageBuildDockerfileMissing")]
                )
            }
            do {
                let data = try Data(contentsOf: dockerfileURL)
                return (standardizedContext.path, data, nil)
            } catch {
                throw NSError(
                    domain: "Build",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "imageBuildDockerfileUnreadable")]
                )
            }
        }
    }

    /// Resolves `relativePath` strictly inside `context` (no absolute path, no escape via `..`).
    static func resolveDockerfileURL(context: URL, relativePath: String) throws -> URL {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let rel = trimmed.isEmpty ? "Dockerfile" : trimmed
        let base = context.standardizedFileURL
        guard !rel.hasPrefix("/") else {
            throw NSError(
                domain: "Build",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "imageBuildDockerfilePathInvalid")]
            )
        }
        let candidate = URL(fileURLWithPath: rel, isDirectory: false, relativeTo: base).standardizedFileURL
        let basePath = base.path
        let resolvedPath = candidate.path
        guard resolvedPath.hasPrefix(basePath + "/") else {
            throw NSError(
                domain: "Build",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "imageBuildDockerfilePathInvalid")]
            )
        }
        return candidate
    }

    private func runBuildKitPipeline(tag: String, contextDirPath: String, dockerfileData: Data) async throws {
        // 1. Ensure builder running
        let container: ContainerSnapshot
        do {
            container = try await containerClient.get(id: "buildkit")
        } catch {
            throw NSError(
                domain: "Build",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "builderNotFound")]
            )
        }

        let fh: FileHandle
        do {
            fh = try await containerClient.dial(id: container.id, port: 8088)
        } catch {
            do {
                let io = try ProcessIO.create(tty: true, interactive: false, detach: true)
                defer { _ = try? io.close() }
                let process = try await containerClient.bootstrap(id: container.id, stdio: io.stdio)
                try await process.start()
                try await Task.sleep(for: .seconds(5))
                fh = try await containerClient.dial(id: container.id, port: 8088)
            } catch {
                throw NSError(
                    domain: "Build",
                    code: 7,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "imageBuildFailedToStartBuilder \(error.localizedDescription)")]
                )
            }
        }

        // 2. Create Builder
        let threadGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let builder = try Builder(socket: fh, group: threadGroup)
        let _ = try await builder.info()

        // 3. Export path
        let systemHealth = try await ClientHealthCheck.ping(timeout: .seconds(10))
        let exportPath = systemHealth.appRoot.appendingPathComponent("builder")
        let buildID = UUID().uuidString
        let tempExportURL = exportPath.appendingPathComponent(buildID)
        try FileManager.default.createDirectory(at: tempExportURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempExportURL) }

        let normalizedTag = try ClientImage.normalizeReference(tag)

        var export = try Builder.BuildExport(from: "type=oci")
        export.destination = tempExportURL.appendingPathComponent("out.tar")

        let platform = try Platform(from: "linux/arm64")

        let config = Builder.BuildConfig(
            buildID: buildID,
            contentStore: RemoteContentStoreClient(),
            buildArgs: [],
            secrets: [:],
            contextDir: contextDirPath,
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

        status = .building
        try await builder.build(config)

        status = .unpacking
        guard let dest = export.destination else {
            throw NSError(domain: "Build", code: 1, userInfo: [NSLocalizedDescriptionKey: "Export destination missing"])
        }
        let result = try await ClientImage.load(from: dest.path, force: false)
        for image in result.images {
            try await image.unpack(platform: nil)
            _ = try await image.tag(new: normalizedTag)
        }

        try? await ImagesStore.shared.collect()
    }
}
