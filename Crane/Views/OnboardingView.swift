//
//  OnboardingView.swift
//  Crane
//

import SwiftUI

struct OnboardingView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                stepBody
                    .padding(Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
        }
        .frame(minWidth: 540, minHeight: 460)
        .task(id: viewModel.step) {
            await runOnStepEnter()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            SwiftUI.Image(systemName: "shippingbox.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("onboardingTitle")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(stepLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            stepIndicator
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var stepLabel: LocalizedStringKey {
        switch viewModel.step {
        case .welcome: return "onboardingStepWelcome"
        case .cli: return "onboardingStepCLI"
        case .apiserver: return "onboardingStepApiserver"
        case .rosetta: return "onboardingStepRosetta"
        case .notifications: return "onboardingStepNotifications"
        case .done: return "onboardingStepDone"
        }
    }

    private var stepIndicator: some View {
        Text("\(viewModel.step.rawValue + 1) / \(OnboardingStep.allCases.count)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    // MARK: - Step body

    @ViewBuilder
    private var stepBody: some View {
        switch viewModel.step {
        case .welcome:
            welcomeStep
        case .cli:
            cliStep
        case .apiserver:
            apiserverStep
        case .rosetta:
            rosettaStep
        case .notifications:
            notificationsStep
        case .done:
            doneStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("onboardingWelcomeHeading")
                .font(.title2.bold())
            Text("onboardingWelcomeBody")
                .foregroundStyle(.secondary)
        }
    }

    private var cliStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("onboardingCLIHeading").font(.headline)
            Text("onboardingCLIBody").foregroundStyle(.secondary)
            statusRow(viewModel.cliStatus)
            if case .failed = viewModel.cliStatus {
                Link("installContainerCLI",
                     destination: URL(string: "https://github.com/apple/container")!)
            }
        }
    }

    private var apiserverStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("onboardingApiserverHeading").font(.headline)
            Text("onboardingApiserverBody").foregroundStyle(.secondary)
            Toggle("launchContainerizationService", isOn: $viewModel.autoLaunchService)
            HStack {
                SpinnerButton(isLoading: viewModel.apiserverStatus == .running) {
                    Task { await viewModel.startApiserver() }
                } label: {
                    Text("onboardingApiserverStartNow")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.apiserverStatus == .running)

                Button("skip") { viewModel.skipApiserver() }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.apiserverStatus == .running)
            }
            statusRow(viewModel.apiserverStatus)
        }
    }

    private var rosettaStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("onboardingRosettaHeading").font(.headline)
            Text("onboardingRosettaBody").foregroundStyle(.secondary)
            switch viewModel.rosettaStatus {
            case .notSupported(let msg):
                Label(msg, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            default:
                HStack {
                    SpinnerButton(isLoading: viewModel.rosettaStatus == .running) {
                        Task { await viewModel.installRosetta() }
                    } label: {
                        Text("onboardingRosettaInstall")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.rosettaStatus == .running ||
                              statusIsOK(viewModel.rosettaStatus))

                    Button("skip") { viewModel.skipRosetta() }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.rosettaStatus == .running)
                }
                statusRow(viewModel.rosettaStatus)
            }
        }
    }

    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("onboardingNotificationsHeading").font(.headline)
            Text("onboardingNotificationsBody").foregroundStyle(.secondary)
            HStack {
                SpinnerButton(isLoading: viewModel.notificationsStatus == .running) {
                    Task { await viewModel.requestNotifications() }
                } label: {
                    Text("onboardingNotificationsEnable")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.notificationsStatus == .running)

                Button("skip") { viewModel.skipNotifications() }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.notificationsStatus == .running)
            }
            statusRow(viewModel.notificationsStatus)
        }
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("onboardingDoneHeading").font(.title2.bold())
            Text("onboardingDoneBody").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                summaryRow("onboardingStepCLI", status: viewModel.cliStatus)
                summaryRow("onboardingStepApiserver", status: viewModel.apiserverStatus)
                summaryRow("onboardingStepRosetta", status: viewModel.rosettaStatus)
                summaryRow("onboardingStepNotifications", status: viewModel.notificationsStatus)
            }
            .padding(Spacing.sm)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Status helpers

    private func statusIsOK(_ s: OnboardingStepStatus) -> Bool {
        if case .ok = s { return true }
        return false
    }

    @ViewBuilder
    private func statusRow(_ status: OnboardingStepStatus) -> some View {
        switch status {
        case .idle:
            EmptyView()
        case .running:
            HStack(spacing: Spacing.sm) {
                ProgressView().controlSize(.small)
                Text("onboardingWorking").foregroundStyle(.secondary)
            }
        case .ok(let detail):
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                SwiftUI.Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                if let detail {
                    Text(detail)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    Text("onboardingOK").foregroundStyle(.secondary)
                }
            }
        case .failed(let msg):
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                SwiftUI.Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                Text(msg).foregroundStyle(.red).textSelection(.enabled).lineLimit(4)
            }
        case .skipped:
            HStack(spacing: Spacing.sm) {
                SwiftUI.Image(systemName: "forward.fill").foregroundStyle(.secondary)
                Text("onboardingSkipped").foregroundStyle(.secondary)
            }
        case .notSupported(let msg):
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                SwiftUI.Image(systemName: "info.circle").foregroundStyle(.secondary)
                Text(msg).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func summaryRow(_ titleKey: LocalizedStringKey, status: OnboardingStepStatus) -> some View {
        HStack {
            Text(titleKey)
            Spacer()
            switch status {
            case .ok: SwiftUI.Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed: SwiftUI.Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            case .skipped: SwiftUI.Image(systemName: "forward.fill").foregroundStyle(.secondary)
            case .notSupported: SwiftUI.Image(systemName: "info.circle").foregroundStyle(.secondary)
            case .running: ProgressView().controlSize(.small)
            case .idle: SwiftUI.Image(systemName: "circle.dashed").foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("back") { viewModel.back() }
                .buttonStyle(.bordered)
                .disabled(viewModel.step == .welcome || viewModel.step == .done)

            Spacer()

            if viewModel.step == .done {
                Button("finish") { viewModel.finish(complete: onFinish) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("continue") { viewModel.advance() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canContinue)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
    }

    private var canContinue: Bool {
        switch viewModel.step {
        case .welcome: return true
        case .cli: return viewModel.cliStatus.isTerminal
        case .apiserver: return viewModel.apiserverStatus.isTerminal
        case .rosetta: return viewModel.rosettaStatus.isTerminal
        case .notifications: return viewModel.notificationsStatus.isTerminal
        case .done: return true
        }
    }

    private func runOnStepEnter() async {
        switch viewModel.step {
        case .cli:
            if !viewModel.cliStatus.isTerminal {
                viewModel.checkCLI()
            }
        case .rosetta:
            if !viewModel.rosettaStatus.isTerminal {
                viewModel.checkRosetta()
            }
        default:
            break
        }
    }
}
