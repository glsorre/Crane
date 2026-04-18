//
//  ImageTagRenameView.swift
//  Crane
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct ImageTagRenameView: View {
    @Binding var isPresented: Bool
    let sourceReference: String

    @State private var imagesStore = ImagesStore.shared
    @State private var newReference: String = ""
    @State private var mode: Mode = .addTag
    @State private var isWorking = false

    private enum Mode: String, CaseIterable, Identifiable, Equatable {
        case addTag
        case rename
        var id: String { rawValue }
    }

    private var trimmedNew: String {
        newReference.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var referenceEmptyMessage: String? {
        trimmedNew.isEmpty ? String(localized: "imageReferenceEmpty") : nil
    }

    private var referenceInvalidMessage: String? {
        guard !trimmedNew.isEmpty else { return nil }
        do {
            _ = try ClientImage.normalizeReference(trimmedNew)
            return nil
        } catch {
            return String(localized: "imageReferenceInvalid")
        }
    }

    private var canApply: Bool {
        guard !isWorking else { return false }
        guard referenceEmptyMessage == nil, referenceInvalidMessage == nil else { return false }
        return !trimmedNew.isEmpty
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Label(String(localized: "imageTagSheetTitle"), systemImage: "tag.fill")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)

            Form {
                Section(String(localized: "imageTagSourceLabel")) {
                    Text(sourceReference)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(.vertical, Spacing.sm)
                }

                Section(String(localized: "imageTagNewReference")) {
                    VStack(alignment: .leading, spacing: Spacing.subsection) {
                        TextField(String(localized: "imageTagNewReference"), text: $newReference)
                            .font(.system(.body, design: .monospaced))

                        if let message = referenceEmptyMessage {
                            InlineErrorText(message: message)
                        } else if let message = referenceInvalidMessage {
                            InlineErrorText(message: message)
                        }
                    }
                    .padding(.vertical, Spacing.sm)
                }

                Section(String(localized: "imageTagModeSection")) {
                    Picker("", selection: $mode) {
                        Text(String(localized: "imageTagModeAdd")).tag(Mode.addTag)
                        Text(String(localized: "imageTagModeRename")).tag(Mode.rename)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)

                    Text(String(localized: "imageTagSheetHint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if mode == .rename {
                        Text(String(localized: "imageTagRenameHint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .groupedDialogFormLayout()

            HStack {
                Button(String(localized: "cancel")) {
                    isPresented = false
                }
                .buttonStyle(.glass)

                Spacer()

                SpinnerButton(isLoading: isWorking) {
                    Task {
                        await apply()
                    }
                } label: {
                    Label(String(localized: "imageTagApply"), systemImage: "checkmark")
                }
                .buttonStyle(.glassProminent)
                .disabled(!canApply)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .frame(width: 520, height: mode == .rename ? 500 : 440)
        .padding(Spacing.md)
        .animation(.easeInOut(duration: 0.2), value: mode)
    }

    private func apply() async {
        isWorking = true
        defer { isWorking = false }

        let ok: Bool
        switch mode {
        case .addTag:
            ok = await imagesStore.tagImage(sourceReference: sourceReference, newReference: trimmedNew)
        case .rename:
            ok = await imagesStore.renameImage(sourceReference: sourceReference, newReference: trimmedNew)
        }

        if ok {
            newReference = ""
            isPresented = false
        }
    }
}
