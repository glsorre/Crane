//
//  ImageFetchView.swift
//  Crane
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct ImageFetchView: View {
    @Binding var isPresented: Bool
    @State private var imagesStore = ImagesStore.shared
    @State private var reference: String = ""
    @State private var isFetching = false
    @State private var fetchError: String?

    private var trimmedReference: String {
        reference.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var referenceEmptyMessage: String? {
        trimmedReference.isEmpty ? String(localized: "imageReferenceEmpty") : nil
    }

    private var referenceInvalidMessage: String? {
        guard !trimmedReference.isEmpty else { return nil }
        do {
            _ = try ClientImage.normalizeReference(trimmedReference)
            return nil
        } catch {
            return String(localized: "imageReferenceInvalid")
        }
    }

    private var normalizedReference: String? {
        guard !trimmedReference.isEmpty else { return nil }
        return try? ClientImage.normalizeReference(trimmedReference)
    }

    private var canFetch: Bool {
        guard !isFetching else { return false }
        guard referenceEmptyMessage == nil, referenceInvalidMessage == nil else { return false }
        return !trimmedReference.isEmpty
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Label("fetchImage", systemImage: "arrow.down.circle.fill")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)

            Form {
                Section(String(localized: "fetchImageUrl")) {
                    VStack(alignment: .leading, spacing: Spacing.subsection) {
                        TextField(String(localized: "fetchImageUrl"), text: $reference)
                            .font(.system(.body, design: .monospaced))

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
            .groupedDialogFormLayout()

            if let fetchError {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    SwiftUI.Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(fetchError)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .lineLimit(4)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }

            HStack {
                Button(String(localized: "cancel")) {
                    isPresented = false
                }
                .buttonStyle(.glass)

                Spacer()

                SpinnerButton(isLoading: isFetching) {
                    Task {
                        await performFetch()
                    }
                } label: {
                    Label(String(localized: "fetchImage"), systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.glassProminent)
                .disabled(!canFetch)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
        .frame(width: 520, height: 420)
        .padding(Spacing.md)
        .onChange(of: reference) {
            fetchError = nil
        }
    }

    private func performFetch() async {
        fetchError = nil
        isFetching = true
        defer { isFetching = false }

        do {
            try await imagesStore.fetchImage(reference: trimmedReference)
            reference = ""
            isPresented = false
        } catch {
            fetchError = error.localizedDescription
        }
    }
}
