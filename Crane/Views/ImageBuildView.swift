//
//  ImageBuildView.swift
//  Crane
//

import ContainerAPIClient
import ContainerResource
import Observation
import SwiftUI
import UniformTypeIdentifiers

struct ImageBuildView: View {
    @Binding var isPresented: Bool
    @Environment(\.craneStores) private var stores
    private var buildViewModel: BuildViewModel { stores.build }
    @State private var tag: String = ""
    @State private var text: String = "FROM alpine:latest\n"
    @State private var buildSourceMode: BuildSourceMode = .paste
    @State private var contextFolderURL: URL?
    /// True when `contextFolderURL` has an active `startAccessingSecurityScopedResource` that must be balanced with `stopAccessingSecurityScopedResource`.
    @State private var contextFolderHasSecurityScopedAccess = false
    @State private var dockerfileRelativePath: String = "Dockerfile"
    @State private var showFolderImporter = false

    private enum BuildSourceMode: String, CaseIterable, Identifiable, Equatable {
        case paste
        case localFolder
        var id: String { rawValue }
    }

    private var trimmedTag: String {
        tag.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDockerfile: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDockerfilePath: String {
        dockerfileRelativePath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var tagEmptyValidationMessage: String? {
        trimmedTag.isEmpty ? String(localized: "imageBuildTagEmpty") : nil
    }

    private var tagInvalidValidationMessage: String? {
        guard !trimmedTag.isEmpty else { return nil }
        do {
            _ = try ClientImage.normalizeReference(trimmedTag)
            return nil
        } catch {
            return String(localized: "imageReferenceInvalid")
        }
    }

    private var dockerfileEmptyValidationMessage: String? {
        guard buildSourceMode == .paste else { return nil }
        return trimmedDockerfile.isEmpty ? String(localized: "imageBuildDockerfileEmpty") : nil
    }

    private var localFolderValidationMessage: String? {
        guard buildSourceMode == .localFolder else { return nil }
        guard let url = contextFolderURL else {
            return String(localized: "imageBuildFolderEmpty")
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return String(localized: "imageBuildContextNotDirectory")
        }
        guard
            let dockerURL = ImageBuildSource.resolvedDockerfileURL(
                contextDirectory: url,
                dockerfileRelativePath: dockerfileRelativePath
            )
        else {
            return String(localized: "imageBuildDockerfilePathInvalid")
        }
        guard FileManager.default.fileExists(atPath: dockerURL.path) else {
            return String(localized: "imageBuildDockerfileMissing")
        }
        return nil
    }

    private var canBuild: Bool {
        guard !buildViewModel.status.isBuilding else { return false }
        guard tagEmptyValidationMessage == nil, tagInvalidValidationMessage == nil else { return false }
        switch buildSourceMode {
        case .paste:
            guard dockerfileEmptyValidationMessage == nil else { return false }
        case .localFolder:
            guard localFolderValidationMessage == nil else { return false }
        }
        return true
    }

    var body: some View {
        DialogContainer(
            isPresented: $isPresented,
            title: "buildImage",
            systemImage: "hammer.fill",
            workingLabel: "buildInProgress",
            canSubmit: canBuild,
            externalStatus: buildViewModel.status.dialogStatus,
            perform: {
                switch buildSourceMode {
                case .paste:
                    let capturedTag = trimmedTag
                    let capturedText = text
                    Task { await buildViewModel.build(tag: capturedTag, dockerfileContent: capturedText) }
                case .localFolder:
                    guard let url = contextFolderURL else { return }
                    let capturedTag = trimmedTag
                    let capturedPath = trimmedDockerfilePath.isEmpty ? "Dockerfile" : trimmedDockerfilePath
                    let scopedURL: URL? = contextFolderHasSecurityScopedAccess ? url : nil
                    // Hand ownership of the security scope to BuildViewModel so the dialog's
                    // onDisappear/onChange teardown doesn't release it while BuildKit is still
                    // streaming the context.
                    contextFolderHasSecurityScopedAccess = false
                    Task {
                        await buildViewModel.build(
                            tag: capturedTag,
                            source: .localContext(
                                contextDirectory: url,
                                dockerfileRelativePath: capturedPath
                            ),
                            securityScopedURL: scopedURL
                        )
                    }
                }
                isPresented = false
            },
            primaryLabel: {
                Label(String(localized: "build"), systemImage: "hammer")
            },
            content: {
                Section(String(localized: "imageBuildSourceSection")) {
                    Picker("", selection: $buildSourceMode) {
                        Text(String(localized: "imageBuildSourcePaste")).tag(BuildSourceMode.paste)
                        Text(String(localized: "imageBuildSourceLocalFolder")).tag(BuildSourceMode.localFolder)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .padding(.vertical, Spacing.sm)
                }

                Section(String(localized: "imageTag")) {
                    VStack(alignment: .leading, spacing: Spacing.subsection) {
                        TextField(String(localized: "imageTag"), text: $tag)
                            .font(.system(.body, design: .monospaced))

                        if let message = tagEmptyValidationMessage {
                            InlineErrorText(message: message)
                        } else if let message = tagInvalidValidationMessage {
                            InlineErrorText(message: message)
                        }
                    }
                    .padding(.vertical, Spacing.sm)
                }

                if buildSourceMode == .paste {
                    Section(String(localized: "dockerfile")) {
                        VStack(alignment: .leading, spacing: Spacing.subsection) {
                            Text(String(localized: "imageBuildDockerfileHint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            DockerfileEditor(text: $text)
                                .frame(minHeight: 280)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.separator, lineWidth: 0.5)
                                )

                            if let message = dockerfileEmptyValidationMessage {
                                InlineErrorText(message: message)
                            }
                        }
                        .padding(.vertical, Spacing.sm)
                    }
                } else {
                    Section(String(localized: "imageBuildContextSection")) {
                        VStack(alignment: .leading, spacing: Spacing.subsection) {
                            Text(String(localized: "imageBuildContextHint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(alignment: .center, spacing: Spacing.sm) {
                                Button(String(localized: "imageBuildChooseFolder")) {
                                    showFolderImporter = true
                                }
                                .buttonStyle(.bordered)

                                if let contextFolderURL {
                                    PathLabel(path: contextFolderURL.path, host: true)
                                } else {
                                    Text("—")
                                        .foregroundStyle(.secondary)
                                        .font(.callout)
                                }
                            }

                            if let message = localFolderValidationMessage {
                                InlineErrorText(message: message)
                            }
                        }
                        .padding(.vertical, Spacing.sm)
                    }

                    Section(String(localized: "imageBuildDockerfilePathLabel")) {
                        VStack(alignment: .leading, spacing: Spacing.subsection) {
                            Text(String(localized: "imageBuildDockerfilePathHint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField("Dockerfile", text: $dockerfileRelativePath)
                                .font(.system(.body, design: .monospaced))
                        }
                        .padding(.vertical, Spacing.sm)
                    }
                }
            }
        )
        .alert(
            String(localized: "rosettaInstallerTitle"),
            isPresented: Bindable(buildViewModel).rosettaInstallerAlertPresented
        ) {
            Button(String(localized: "rosettaInstallerInstallButton")) {
                buildViewModel.resolveRosettaInstallerPrompt(.installRosetta)
            }
            Button(String(localized: "rosettaInstallerContinueWithoutButton")) {
                buildViewModel.resolveRosettaInstallerPrompt(.continueWithoutRosetta)
            }
            Button(String(localized: "cancel"), role: .cancel) {
                buildViewModel.resolveRosettaInstallerPrompt(.cancel)
            }
        } message: {
            Text(String(localized: "rosettaInstallerMessage"))
        }
        .frame(width: 720, height: buildSourceMode == .paste ? 640 : 620)
        .padding(Spacing.md)
        .animation(.easeInOut(duration: 0.25), value: buildViewModel.status)
        .animation(.easeInOut(duration: 0.2), value: buildSourceMode)
        .onChange(of: buildSourceMode) { _, newMode in
            if newMode != .localFolder {
                stopSecurityScopedAccessForContextFolder()
                contextFolderURL = nil
            }
        }
        .onChange(of: isPresented) { _, presented in
            if presented {
                // Only clear terminal state on re-open; preserve in-flight background build.
                if case .failed = buildViewModel.status {
                    buildViewModel.dismissTerminalStatus()
                } else if case .success = buildViewModel.status {
                    buildViewModel.dismissTerminalStatus()
                }
            } else {
                if buildViewModel.rosettaInstallerAlertPresented {
                    buildViewModel.resolveRosettaInstallerPrompt(.cancel)
                }
                stopSecurityScopedAccessForContextFolder()
                contextFolderURL = nil
            }
        }
        .onDisappear {
            stopSecurityScopedAccessForContextFolder()
        }
        .fileImporter(
            isPresented: $showFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                stopSecurityScopedAccessForContextFolder()
                contextFolderURL = url
                contextFolderHasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
            case .failure:
                break
            }
        }
    }

    private func stopSecurityScopedAccessForContextFolder() {
        guard contextFolderHasSecurityScopedAccess, let url = contextFolderURL else { return }
        url.stopAccessingSecurityScopedResource()
        contextFolderHasSecurityScopedAccess = false
    }
}

extension BuildStatus {
    fileprivate var dialogStatus: DialogStatus {
        switch self {
        case .idle: return .idle
        case .startingBuilder: return .working("buildStarting")
        case .building: return .working("buildInProgress")
        case .unpacking: return .working("buildUnpacking")
        case .success: return .success
        case .failed(let msg): return .error(msg)
        }
    }
}
