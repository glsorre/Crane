//
//  DialogContainer.swift
//  Crane
//

import SwiftUI

enum DialogStatus: Equatable {
    case idle
    case working(LocalizedStringKey)
    case error(String)
    case success

    var isWorking: Bool {
        if case .working = self { return true }
        return false
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

struct DialogContainer<Content: View, PrimaryLabel: View>: View {
    @Binding var isPresented: Bool
    let title: LocalizedStringKey
    let systemImage: String
    let workingLabel: LocalizedStringKey
    let canSubmit: Bool
    /// Set for long-running operations that must outlive dialog dismissal (e.g. image builds).
    /// When `nil`, the dialog drives its own status from `perform`'s throw/return and auto-closes on success.
    let externalStatus: DialogStatus?
    let clearErrorTrigger: AnyHashable?
    let perform: () async throws -> Void
    @ViewBuilder let primaryLabel: () -> PrimaryLabel
    @ViewBuilder let content: () -> Content

    @State private var internalStatus: DialogStatus = .idle

    init(
        isPresented: Binding<Bool>,
        title: LocalizedStringKey,
        systemImage: String,
        workingLabel: LocalizedStringKey = "dialogWorking",
        canSubmit: Bool,
        externalStatus: DialogStatus? = nil,
        clearErrorTrigger: AnyHashable? = nil,
        perform: @escaping () async throws -> Void,
        @ViewBuilder primaryLabel: @escaping () -> PrimaryLabel,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented
        self.title = title
        self.systemImage = systemImage
        self.workingLabel = workingLabel
        self.canSubmit = canSubmit
        self.externalStatus = externalStatus
        self.clearErrorTrigger = clearErrorTrigger
        self.perform = perform
        self.primaryLabel = primaryLabel
        self.content = content
    }

    private var status: DialogStatus {
        externalStatus ?? internalStatus
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)

            Form {
                content()
            }
            .groupedDialogFormLayout()

            statusStrip

            HStack {
                Button(String(localized: "cancel")) {
                    isPresented = false
                }
                .buttonStyle(.glass)
                .disabled(status.isWorking)

                Spacer()

                SpinnerButton(isLoading: status.isWorking) {
                    Task { await submit() }
                } label: {
                    primaryLabel()
                }
                .buttonStyle(.glassProminent)
                .disabled(!canSubmit || status.isWorking)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .onChange(of: status) { _, newStatus in
            if newStatus == .success {
                isPresented = false
            }
        }
        .onChange(of: clearErrorTrigger) { _, _ in
            if externalStatus == nil, internalStatus.isError {
                internalStatus = .idle
            }
        }
    }

    @ViewBuilder
    private var statusStrip: some View {
        switch status {
        case .idle, .success:
            EmptyView()
        case .working(let label):
            HStack(alignment: .center, spacing: Spacing.sm) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        case .error(let message):
            HStack(alignment: .top, spacing: Spacing.sm) {
                SwiftUI.Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .lineLimit(4)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
    }

    private func submit() async {
        if externalStatus == nil {
            internalStatus = .working(workingLabel)
        }
        do {
            try await perform()
            if externalStatus == nil {
                internalStatus = .success
            }
        } catch {
            if externalStatus == nil {
                internalStatus = .error(error.localizedDescription)
            }
        }
    }
}
