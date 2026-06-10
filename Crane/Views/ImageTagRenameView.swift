//
//  ImageTagRenameView.swift
//  Crane
//

import ContainerAPIClient
import ContainerPersistence
import ContainerResource
import SwiftUI

struct ImageTagRenameView: View {
    @Binding var isPresented: Bool
    let sourceReference: String

    @Environment(\.craneStores) private var stores
    private var imagesStore: ImagesStore { stores.images }
    @State private var newReference: String = ""
    @State private var containerSystemConfig: ContainerSystemConfig?
    @FocusState private var isReferenceFocused: Bool
    @State private var mode: Mode = .addTag

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
        guard let containerSystemConfig else { return nil }
        do {
            _ = try ClientImage.normalizeReference(trimmedNew, containerSystemConfig: containerSystemConfig)
            return nil
        } catch {
            return String(localized: "imageReferenceInvalid")
        }
    }

    private var canApply: Bool {
        referenceEmptyMessage == nil && referenceInvalidMessage == nil && !trimmedNew.isEmpty
    }

    var body: some View {
        DialogContainer(
            isPresented: $isPresented,
            title: "imageTagSheetTitle",
            systemImage: "tag.fill",
            workingLabel: "imageTagSheetTitle",
            canSubmit: canApply,
            clearErrorTrigger: AnyHashable("\(newReference)|\(mode.rawValue)"),
            perform: {
                switch mode {
                case .addTag:
                    try await imagesStore.tagImage(sourceReference: sourceReference, newReference: trimmedNew)
                case .rename:
                    try await imagesStore.renameImage(sourceReference: sourceReference, newReference: trimmedNew)
                }
            },
            primaryLabel: {
                Label(String(localized: "imageTagApply"), systemImage: "checkmark")
            },
            content: {
                Section(String(localized: "imageTagSourceLabel")) {
                    Text(sourceReference)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(.vertical, Spacing.sm)
                }

                Section(String(localized: "imageTagNewReference")) {
                    VStack(alignment: .leading, spacing: Spacing.subsection) {
                        TextField(String(localized: "imageTagNewReference"), text: $newReference, prompt: Text(String(localized: "imageTagNewReference")))
                            .font(.system(.body, design: .monospaced))
                            .focused($isReferenceFocused)
                            .premiumTextFieldStyle(
                                isError: referenceInvalidMessage != nil
                            )

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
        )
        .frame(width: 520, height: mode == .rename ? 500 : 440)
        .padding(Spacing.md)
        .animation(.easeInOut(duration: 0.2), value: mode)
        .onAppear {
            isReferenceFocused = true
        }
        .task {
            if containerSystemConfig == nil {
                containerSystemConfig = try? await ConfigurationLoader.load()
            }
        }
    }
}
