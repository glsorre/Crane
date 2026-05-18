//
//  NetworkCreateView.swift
//  Crane
//

import SwiftUI

struct NetworkCreateView: View {
    @Binding var isPresented: Bool
    @Environment(\.craneStores) private var stores
    private var networksStore: NetworksStore { stores.networks }
    @State private var networkID: String = ""

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
        emptyMessage == nil && invalidCharactersMessage == nil && duplicateMessage == nil && !trimmedID.isEmpty
    }

    var body: some View {
        DialogContainer(
            isPresented: $isPresented,
            title: "networkCreateTitle",
            systemImage: "network",
            workingLabel: "networkCreateTitle",
            canSubmit: canCreate,
            clearErrorTrigger: AnyHashable(networkID),
            perform: {
                try await networksStore.createNetwork(id: trimmedID)
            },
            primaryLabel: {
                Label(String(localized: "networkToCreate"), systemImage: "plus")
            },
            content: {
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
        )
        .frame(width: 520, height: 480)
        .padding(Spacing.md)
    }
}
