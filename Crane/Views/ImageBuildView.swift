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
    @State private var buildViewModel = BuildViewModel()
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
        guard let dockerURL = ImageBuildSource.resolvedDockerfileURL(
            contextDirectory: url,
            dockerfileRelativePath: dockerfileRelativePath
        ) else {
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
        VStack(spacing: Spacing.md) {
            HStack {
                Label("buildImage", systemImage: "hammer.fill")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)

            Form {
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
            .groupedDialogFormLayout()

            buildStatusStrip
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)

            HStack {
                Button(String(localized: "cancel")) {
                    isPresented = false
                }
                .buttonStyle(.glass)

                Spacer()

                SpinnerButton(isLoading: buildViewModel.status.isBuilding) {
                    Task {
                        switch buildSourceMode {
                        case .paste:
                            await buildViewModel.build(tag: trimmedTag, dockerfileContent: text)
                        case .localFolder:
                            guard let contextFolderURL else { return }
                            await buildViewModel.build(
                                tag: trimmedTag,
                                source: .localContext(
                                    contextDirectory: contextFolderURL,
                                    dockerfileRelativePath: trimmedDockerfilePath.isEmpty ? "Dockerfile" : trimmedDockerfilePath
                                )
                            )
                        }
                    }
                } label: {
                    Label(String(localized: "build"), systemImage: "hammer")
                }
                .buttonStyle(.glassProminent)
                .disabled(!canBuild)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
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
        .onChange(of: buildViewModel.status) { _, newStatus in
            if case .success = newStatus {
                isPresented = false
            }
        }
        .onChange(of: isPresented) { _, presented in
            if presented {
                buildViewModel.status = .idle
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

    // MARK: - Build status (between form and footer, like ContainerRunView)

    @ViewBuilder
    private var buildStatusStrip: some View {
        switch buildViewModel.status {
        case .idle:
            EmptyView()
        case .success:
            HStack(alignment: .top, spacing: Spacing.sm) {
                SwiftUI.Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(String(localized: "buildSuccess"))
                    .font(.callout)
                    .foregroundStyle(.green)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .failed(let message):
            HStack(alignment: .top, spacing: Spacing.sm) {
                SwiftUI.Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("\(String(localized: "buildFailed")): \(message)")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            HStack(spacing: 0) {
                ForEach(Array(BuildStep.allCases.enumerated()), id: \.offset) { index, step in
                    if index > 0 {
                        Rectangle()
                            .fill(.separator)
                            .frame(width: 16, height: 1)
                    }
                    stepCapsule(step: step, state: stepState(for: step))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private enum BuildStep: Int, CaseIterable {
        case starting, building, unpacking

        var icon: String {
            switch self {
            case .starting: return "gear"
            case .building: return "hammer"
            case .unpacking: return "archivebox"
            }
        }

        var label: String {
            switch self {
            case .starting: return String(localized: "buildStepStarting")
            case .building: return String(localized: "buildStepBuilding")
            case .unpacking: return String(localized: "buildStepUnpacking")
            }
        }
    }

    private enum StepState {
        case pending, active, completed
    }

    private func stepState(for step: BuildStep) -> StepState {
        let currentOrder: Int
        switch buildViewModel.status {
        case .idle: return .pending
        case .startingBuilder: currentOrder = 0
        case .building: currentOrder = 1
        case .unpacking: currentOrder = 2
        case .success, .failed: return .completed
        }
        if step.rawValue < currentOrder { return .completed }
        if step.rawValue == currentOrder { return .active }
        return .pending
    }

    @ViewBuilder
    private func stepCapsule(step: BuildStep, state: StepState) -> some View {
        HStack(spacing: Spacing.xxs) {
            switch state {
            case .active:
                ProgressView()
                    .controlSize(.mini)
            case .completed:
                SwiftUI.Image(systemName: "checkmark")
                    .font(.caption2)
            case .pending:
                SwiftUI.Image(systemName: step.icon)
                    .font(.caption2)
            }
            Text(step.label)
                .font(.caption)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxxs)
        .background(stepBackground(for: state))
        .clipShape(Capsule())
    }

    private func stepBackground(for state: StepState) -> some ShapeStyle {
        switch state {
        case .active: return AnyShapeStyle(.tint)
        case .completed: return AnyShapeStyle(.green.opacity(0.2))
        case .pending: return AnyShapeStyle(.quaternary)
        }
    }
}
