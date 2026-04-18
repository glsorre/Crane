//
//  NetworkCreateView.swift
//  Crane
//

import SwiftUI

struct NetworkCreateView: View {
    @Binding var isPresented: Bool
    @State private var networksStore = NetworksStore.shared
    @State private var networkID: String = ""
    @State private var isCreating = false
    @State private var createError: String?

    private var trimmedID: String {
        networkID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var emptyMessage: String? {
        trimmedID.isEmpty ? String(localized: "networkCreateEmpty") : nil
    }

    private var invalidCharactersMessage: String? {
        guard !trimmedID.isEmpty else { return nil }
        guard ResourceNaming.isValidResourceName(trimmedID) else {
            return String(localized: "networkCreateInvalidChars")
        }
        return nil
    }

    private var duplicateMessage: String? {
        guard !trimmedID.isEmpty, ResourceNaming.isValidResourceName(trimmedID) else { return nil }
        guard networksStore.networks.contains(where: { $0.id == trimmedID }) else { return nil }
        return String(localized: "networkCreateDuplicate")
    }

    private var canCreate: Bool {
        guard !isCreating else { return false }
        guard emptyMessage == nil, invalidCharactersMessage == nil, duplicateMessage == nil else { return false }
        return !trimmedID.isEmpty
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Label("networkCreateTitle", systemImage: "network")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.lg)

            Form {
                Section(String(localized: "Network")) {
                    VStack(alignment: .leading, spacing: Spacing.subsection) {
                        TextField(String(localized: "networkToCreateName"), text: $networkID)
                            .font(.system(.body, design: .monospaced))

                        Text(String(localized: "networkCreateHelper"))
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

                Section(String(localized: "networkCreateOptionsSection")) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        LabeledContent(String(localized: "networkCreateModeLabel")) {
                            Text(String(localized: "networkCreateModeValue"))
                                .foregroundStyle(.secondary)
                        }
                        LabeledContent(String(localized: "networkCreatePluginLabel")) {
                            Text("container-network-vmnet")
                                .font(.callout)
                                .monospaced()
                                .textSelection(.enabled)
                                .foregroundStyle(.secondary)
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
                    Label(String(localized: "networkToCreate"), systemImage: "plus")
                }
                .buttonStyle(.glassProminent)
                .disabled(!canCreate)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.md)
        }
        .frame(width: 520, height: 480)
        .padding(Spacing.md)
        .onChange(of: networkID) {
            createError = nil
        }
    }

    private func performCreate() async {
        createError = nil
        isCreating = true
        defer { isCreating = false }

        do {
            try await networksStore.createNetwork(id: trimmedID)
            networkID = ""
            isPresented = false
        } catch {
            createError = error.localizedDescription
        }
    }
}
