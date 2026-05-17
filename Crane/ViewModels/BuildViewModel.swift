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
import Logging
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

@MainActor
@Observable
class BuildViewModel {
    static let shared = BuildViewModel()

    private let containerClient = ContainerClient()

    /// Upper bound for `Builder.build` (gRPC stream); avoids indefinite UI when BuildKit never closes the stream.
    private static let buildInvocationTimeout: Duration = .seconds(45 * 60)

    /// Auto-clear delay for `.success` so the background banner disappears after the new image lands in the list.
    private static let successBannerDismissDelay: Duration = .seconds(2)

    /// OCI label stamped on locally-built images so the UI can distinguish them from pulled images sharing the same `docker.io/library/...` normalized reference.
    private static let localBuildLabel = "\(Image.localBuildLabelKey)=true"

    var status: BuildStatus = .idle

    /// Tag of the build currently running (or last finished). Drives the background banner label.
    var currentBuildTag: String?

    /// Shown when the builder VM needs Linux Rosetta; user can install it or continue with QEMU (`build.rosetta` off).
    var rosettaInstallerAlertPresented = false

    private var rosettaInstallerContinuation: CheckedContinuation<RosettaInstallerChoice, Never>?

    enum RosettaInstallerChoice: Sendable {
        case installRosetta
        case continueWithoutRosetta
        case cancel
    }

    func resolveRosettaInstallerPrompt(_ choice: RosettaInstallerChoice) {
        rosettaInstallerAlertPresented = false
        rosettaInstallerContinuation?.resume(returning: choice)
        rosettaInstallerContinuation = nil
    }

    private func waitForRosettaInstallerChoice() async -> RosettaInstallerChoice {
        await withCheckedContinuation { cont in
            rosettaInstallerContinuation = cont
            rosettaInstallerAlertPresented = true
        }
    }

    /// Builds from pasted Dockerfile text (legacy single-field flow).
    func build(tag: String, dockerfileContent: String) async {
        await build(tag: tag, source: .pastedDockerfile(dockerfileContent))
    }

    func build(tag: String, source: ImageBuildSource, securityScopedURL: URL? = nil) async {
        defer { securityScopedURL?.stopAccessingSecurityScopedResource() }
        currentBuildTag = tag
        status = .startingBuilder

        do {
            let (contextDirPath, dockerfileData, contextDirToDelete) = try await Task.detached(priority: .userInitiated) {
                try Self.prepareBuildPaths(source: source)
            }.value
            defer {
                if let dir = contextDirToDelete {
                    try? FileManager.default.removeItem(at: dir)
                }
            }

            try await runBuildKitPipeline(tag: tag, contextDirPath: contextDirPath, dockerfileData: dockerfileData)
            status = .success
            scheduleSuccessBannerDismiss()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// User-dismissable error banner: clears terminal state and exposes the hammer button again.
    func dismissTerminalStatus() {
        guard case .failed = status else {
            if case .success = status {
                status = .idle
                currentBuildTag = nil
            }
            return
        }
        status = .idle
        currentBuildTag = nil
    }

    private func scheduleSuccessBannerDismiss() {
        Task { [weak self] in
            try? await Task.sleep(for: Self.successBannerDismissDelay)
            guard let self else { return }
            if case .success = self.status {
                self.status = .idle
                self.currentBuildTag = nil
            }
        }
    }

    /// Resolves context directory and Dockerfile bytes. Returns a temp directory URL to delete after the build when non-nil.
    /// Static + sync + nonisolated: caller is expected to invoke from a detached Task so the MainActor doesn't block on disk I/O.
    nonisolated private static func prepareBuildPaths(source: ImageBuildSource) throws -> (contextDirPath: String, dockerfileData: Data, contextDirToDelete: URL?) {
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
    nonisolated static func resolveDockerfileURL(context: URL, relativePath: String) throws -> URL {
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
        let baseComponents = base.pathComponents
        let resolvedComponents = candidate.pathComponents
        guard resolvedComponents.starts(with: baseComponents),
              resolvedComponents.count > baseComponents.count else {
            throw NSError(
                domain: "Build",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "imageBuildDockerfilePathInvalid")]
            )
        }
        return candidate
    }

    private func runBuildKitPipeline(tag: String, contextDirPath: String, dockerfileData: Data) async throws {
        // 1. Ensure builder running (may run `container builder start` via helpers when missing)
        let container: ContainerSnapshot
        do {
            container = try await containerClient.get(id: "buildkit")
        } catch {
            switch await startBuilderContainerViaCLI() {
            case .builderReady:
                do {
                    container = try await containerClient.get(id: "buildkit")
                } catch {
                    throw NSError(
                        domain: "Build",
                        code: 6,
                        userInfo: [NSLocalizedDescriptionKey: String(localized: "builderNotFound")]
                    )
                }
            case .failed:
                throw NSError(
                    domain: "Build",
                    code: 6,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "builderNotFound")]
                )
            case .needsRosettaChoice:
                let choice = await waitForRosettaInstallerChoice()
                switch choice {
                case .cancel:
                    throw NSError(
                        domain: "Build",
                        code: 8,
                        userInfo: [NSLocalizedDescriptionKey: String(localized: "buildCancelled")]
                    )
                case .continueWithoutRosetta:
                    guard await startBuilderContainerWithRosettaDisabledViaCLI() else {
                        throw NSError(
                            domain: "Build",
                            code: 6,
                            userInfo: [NSLocalizedDescriptionKey: String(localized: "builderNotFound")]
                        )
                    }
                    do {
                        container = try await containerClient.get(id: "buildkit")
                    } catch {
                        throw NSError(
                            domain: "Build",
                            code: 6,
                            userInfo: [NSLocalizedDescriptionKey: String(localized: "builderNotFound")]
                        )
                    }
                case .installRosetta:
                    do {
                        if #available(macOS 13.0, *) {
                            try await LinuxVMRosettaInstaller.installIfNeeded()
                        } else {
                            throw RosettaInstallError.requiresMacOS13
                        }
                    } catch {
                        throw NSError(
                            domain: "Build",
                            code: 10,
                            userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
                        )
                    }
                    guard await runContainerBuilderStartOnly() else {
                        throw NSError(
                            domain: "Build",
                            code: 6,
                            userInfo: [NSLocalizedDescriptionKey: String(localized: "builderNotFound")]
                        )
                    }
                    do {
                        container = try await containerClient.get(id: "buildkit")
                    } catch {
                        throw NSError(
                            domain: "Build",
                            code: 6,
                            userInfo: [NSLocalizedDescriptionKey: String(localized: "builderNotFound")]
                        )
                    }
                }
            }
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

        // 2. Builder session: keep `Builder` scoped so it releases the socket before we shut down the
        //    event loop group and close the dial `FileHandle`.
        let threadGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        do {
            try await runBuildKitClientSession(
                fh: fh,
                threadGroup: threadGroup,
                tag: tag,
                contextDirPath: contextDirPath,
                dockerfileData: dockerfileData
            )
        } catch {
            try? await shutdownThreadGroupGracefully(threadGroup)
            try? fh.close()
            throw error
        }

        try? await shutdownThreadGroupGracefully(threadGroup)
        try? fh.close()
    }

    /// `quiet: false` is required: with `quiet: true`, ContainerBuild's `BuildStdio` skips IO packets without sending `ClientStream` replies, which can stall the build stream indefinitely.
    private func runBuildKitClientSession(
        fh: FileHandle,
        threadGroup: MultiThreadedEventLoopGroup,
        tag: String,
        contextDirPath: String,
        dockerfileData: Data
    ) async throws {
        let builder = try Builder(socket: fh, group: threadGroup, logger: Logger(label: "BuildViewModel"))
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
            dockerignore: nil,
            labels: [Self.localBuildLabel],
            noCache: false,
            platforms: [platform],
            terminal: nil,
            tags: [normalizedTag],
            target: "",
            quiet: false,
            exports: [export],
            cacheIn: [],
            cacheOut: [],
            pull: true
        )

        status = .building
        let buildKitBuilder = builder
        let buildKitConfig = config
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await Task.detached(priority: .userInitiated) {
                    try await buildKitBuilder.build(buildKitConfig)
                }.value
            }
            group.addTask {
                try await Task.sleep(for: Self.buildInvocationTimeout)
                throw NSError(
                    domain: "Build",
                    code: 11,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "imageBuildTimedOut")]
                )
            }
            try await group.next()
            group.cancelAll()
        }

        status = .unpacking
        guard let dest = export.destination else {
            throw NSError(domain: "Build", code: 1, userInfo: [NSLocalizedDescriptionKey: "Export destination missing"])
        }
        let result = try await ClientImage.load(from: dest.path, force: false)
        for image in result.images {
            try await image.unpack(platform: nil)
            _ = try await image.tag(new: normalizedTag)
        }

        _ = try? await ImagesStore.shared.collect()
    }

    private func shutdownThreadGroupGracefully(_ threadGroup: MultiThreadedEventLoopGroup) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            threadGroup.shutdownGracefully { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
