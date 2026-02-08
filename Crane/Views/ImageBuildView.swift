//
//  ImageBuildView.swift
//  Crane
//

import SwiftUI

struct ImageBuildView: View {
    @Binding var isPresented: Bool
    @State private var buildViewModel = BuildViewModel()
    @State private var tag: String = ""
    @State private var text: String = "FROM alpine:latest\n"

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                Label("buildImage", systemImage: "hammer.fill")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                TextField(String(localized: "imageTag"), text: $tag)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(maxWidth: 260)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            // Editor body
            DockerfileEditor(text: $text)
                .frame(minHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.separator, lineWidth: 0.5)
                )
                .padding(.horizontal, Spacing.md)

            // Progress indicator
            buildProgressView
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)

            // Footer bar
            HStack {
                Button(String(localized: "cancel")) {
                    isPresented = false
                }
                .buttonStyle(.glass)
                Spacer()
                SpinnerButton(isLoading: buildViewModel.status.isBuilding) {
                    Task {
                        await buildViewModel.build(tag: tag, dockerfileContent: text)
                    }
                } label: {
                    Label(String(localized: "build"), systemImage: "hammer")
                }
                .buttonStyle(.glassProminent)
                .disabled(tag.isEmpty || text.isEmpty || buildViewModel.status.isBuilding)
            }
            .padding(Spacing.sm)
        }
        .frame(minWidth: 640, minHeight: 520)
        .animation(.easeInOut(duration: 0.25), value: buildViewModel.status)
    }

    // MARK: - Build Progress

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
    private var buildProgressView: some View {
        switch buildViewModel.status {
        case .idle:
            EmptyView()
        case .success:
            HStack(spacing: Spacing.xs) {
                SwiftUI.Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(String(localized: "buildSuccess"))
                    .font(.callout)
                    .foregroundStyle(.green)
            }
            .padding(.vertical, Spacing.xxs)
        case .failed(let message):
            HStack(alignment: .top, spacing: Spacing.xs) {
                SwiftUI.Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text("\(String(localized: "buildFailed")): \(message)")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
            .padding(.vertical, Spacing.xxs)
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
            .padding(.vertical, Spacing.xxs)
        }
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
