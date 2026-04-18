//
//  VolumeCreateView.swift
//  Crane
//

import SwiftUI

struct VolumeCreateView: View {
    @Binding var isPresented: Bool
    @State private var volumesStore = VolumesStore.shared
    @State private var volumeName: String = ""
    @State private var isCreating = false
    @State private var createError: String?

    private var trimmedName: String {
        volumeName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emptyMessage: String? {
        trimmedName.isEmpty ? String(localized: "volumeCreateEmpty") : nil
    }

    private var invalidCharactersMessage: String? {
        guard !trimmedName.isEmpty else { return nil }
        guard ResourceNaming.isValidResourceName(trimmedName) else {
            return String(localized: "volumeCreateInvalidChars")
        }
        return nil
    }

    private var duplicateMessage: String? {
        guard !trimmedName.isEmpty, ResourceNaming.isValidResourceName(trimmedName) else { return nil }
        guard volumesStore.volumes.contains(where: { $0.id == trimmedName }) else { return nil }
        return String(localized: "volumeCreateDuplicate")
    }

    private var canCreate: Bool {
        guard !isCreating else { return false }
        guard emptyMessage == nil, invalidCharactersMessage == nil, duplicateMessage == nil else { return false }
        return !trimmedName.isEmpty
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Label("volumeCreateTitle", systemImage: "externaldrive.fill")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)

            Form {
                Section(String(localized: "Volume")) {
                    VStack(alignment: .leading, spacing: Spacing.subsection) {
                        TextField(String(localized: "volumeToCreateName"), text: $volumeName)
                            .font(.system(.body, design: .monospaced))

                        Text(String(localized: "volumeCreateHelper"))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let message = emptyMessage {
                            InlineErrorText(message: message)
                        } else if let message = invalidCharactersMessage {
                            InlineErrorText(message: message)
                        } else if let message = duplicateMessage {
                            InlineErrorText(message: message)
                        }
                    }
                    .padding(.vertical, Spacing.sm)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 0)

            if let createError {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    SwiftUI.Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(createError)
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

                SpinnerButton(isLoading: isCreating) {
                    Task {
                        await performCreate()
                    }
                } label: {
                    Label(String(localized: "volumeToCreate"), systemImage: "plus")
                }
                .buttonStyle(.glassProminent)
                .disabled(!canCreate)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.md)
        }
        .frame(width: 520, height: 380)
        .padding(Spacing.md)
        .onChange(of: volumeName) {
            createError = nil
        }
    }

    private func performCreate() async {
        createError = nil
        isCreating = true
        defer { isCreating = false }

        do {
            try await volumesStore.createVolume(name: trimmedName)
            volumeName = ""
            isPresented = false
        } catch {
            createError = error.localizedDescription
        }
    }
}
