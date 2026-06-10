//
//  ImageFetchView.swift
//  Crane
//

import ContainerAPIClient
import ContainerPersistence
import ContainerResource
import SwiftUI

struct ImageFetchView: View {
    @Binding var isPresented: Bool
    @Environment(\.craneStores) private var stores
    private var imagesStore: ImagesStore { stores.images }
    @State private var reference: String = ""
    @State private var containerSystemConfig: ContainerSystemConfig?
    @FocusState private var isReferenceFocused: Bool

    private var trimmedReference: String {
        reference.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var referenceEmptyMessage: String? {
        trimmedReference.isEmpty ? String(localized: "imageReferenceEmpty") : nil
    }

    private var referenceInvalidMessage: String? {
        guard !trimmedReference.isEmpty else { return nil }
        guard let containerSystemConfig else { return nil }
        do {
            _ = try ClientImage.normalizeReference(trimmedReference, containerSystemConfig: containerSystemConfig)
            return nil
        } catch {
            return String(localized: "imageReferenceInvalid")
        }
    }

    private var normalizedReference: String? {
        guard !trimmedReference.isEmpty else { return nil }
        guard let containerSystemConfig else { return nil }
        return try? ClientImage.normalizeReference(trimmedReference, containerSystemConfig: containerSystemConfig)
    }

    private var canFetch: Bool {
        referenceEmptyMessage == nil && referenceInvalidMessage == nil && !trimmedReference.isEmpty
    }

    var body: some View {
        DialogContainer(
            isPresented: $isPresented,
            title: "fetchImage",
            systemImage: "arrow.down.circle.fill",
            workingLabel: "fetchImage",
            canSubmit: canFetch,
            clearErrorTrigger: AnyHashable(reference),
            perform: {
                try await imagesStore.fetchImage(reference: trimmedReference)
            },
            primaryLabel: {
                Label(String(localized: "fetchImage"), systemImage: "arrow.down.circle.fill")
            },
            content: {
                Section(String(localized: "fetchImageUrl")) {
                    VStack(alignment: .leading, spacing: Spacing.subsection) {
                        TextField(String(localized: "fetchImageUrl"), text: $reference, prompt: Text(String(localized: "fetchImageUrl")))
                            .font(.system(.body, design: .monospaced))
                            .focused($isReferenceFocused)
                            .premiumTextFieldStyle(
                                isError: referenceInvalidMessage != nil
                            )

                        Text(String(localized: "fetchImageHelper"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let normalizedReference, referenceInvalidMessage == nil, referenceEmptyMessage == nil {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(String(localized: "fetchImageNormalizedLabel"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(normalizedReference)
                                    .font(.callout)
                                    .monospaced()
                                    .textSelection(.enabled)
                            }
                        }

                        if let message = referenceEmptyMessage {
                            InlineErrorText(message: message)
                        } else if let message = referenceInvalidMessage {
                            InlineErrorText(message: message)
                        }
                    }
                    .padding(.vertical, Spacing.sm)
                }
            }
        )
        .frame(width: 520, height: 420)
        .padding(Spacing.md)
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
