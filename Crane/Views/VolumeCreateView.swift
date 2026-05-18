//
//  VolumeCreateView.swift
//  Crane
//

import SwiftUI

struct VolumeCreateView: View {
    @Binding var isPresented: Bool
    @Environment(\.craneStores) private var stores
    private var volumesStore: VolumesStore { stores.volumes }
    @State private var volumeName: String = ""

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
        emptyMessage == nil && invalidCharactersMessage == nil && duplicateMessage == nil && !trimmedName.isEmpty
    }

    var body: some View {
        DialogContainer(
            isPresented: $isPresented,
            title: "volumeCreateTitle",
            systemImage: "externaldrive.fill",
            workingLabel: "volumeCreateTitle",
            canSubmit: canCreate,
            clearErrorTrigger: AnyHashable(volumeName),
            perform: {
                try await volumesStore.createVolume(name: trimmedName)
            },
            primaryLabel: {
                Label(String(localized: "volumeToCreate"), systemImage: "plus")
            },
            content: {
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
        )
        .frame(width: 520, height: 380)
        .padding(Spacing.md)
    }
}
