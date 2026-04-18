//
//  ImageBuildView.swift
//  Crane
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct ImageBuildView: View {
    @Binding var isPresented: Bool
    @State private var buildViewModel = BuildViewModel()
    @State private var tag: String = ""
    @State private var text: String = "FROM alpine:latest\n"

    private var trimmedTag: String {
        tag.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDockerfile: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        trimmedDockerfile.isEmpty ? String(localized: "imageBuildDockerfileEmpty") : nil
    }

    private var canBuild: Bool {
        guard !buildViewModel.status.isBuilding else { return false }
        guard tagEmptyValidationMessage == nil,
              dockerfileEmptyValidationMessage == nil,
              tagInvalidValidationMessage == nil
        else { return false }
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
            }
            .formStyle(.grouped)
            .padding(.horizontal, 0)

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
                        await buildViewModel.build(tag: trimmedTag, dockerfileContent: text)
                    }
                } label: {
                    Label(String(localized: "build"), systemImage: "hammer")
                }
                .buttonStyle(.glassProminent)
                .disabled(!canBuild)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.md)
        }
        .frame(width: 720, height: 640)
        .padding(Spacing.md)
        .animation(.easeInOut(duration: 0.25), value: buildViewModel.status)
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
