import SwiftUI

struct KeyValueListEditor: View {
    @Binding var entries: [KeyValueEntry]
    let addLabel: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(entries) { entry in
                let eb = entryBinding(for: entry.id)
                HStack(spacing: 8) {
                    TextField("Key", text: eb.key)
                        .textFieldStyle(.plain)
                        .frame(maxWidth: .infinity)
                    TextField("Value", text: eb.value)
                        .textFieldStyle(.plain)
                        .frame(maxWidth: .infinity)
                    Button {
                        entries.removeAll { $0.id == entry.id }
                    } label: {
                        SwiftUI.Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
            Button {
                entries.append(KeyValueEntry())
            } label: {
                Label(addLabel, systemImage: "plus")
            }
            .buttonStyle(.borderless)
        }
    }

    private func entryBinding(for id: UUID) -> Binding<KeyValueEntry> {
        Binding(
            get: { entries.first { $0.id == id } ?? KeyValueEntry() },
            set: { val in
                if let index = entries.firstIndex(where: { $0.id == id }) {
                    entries[index] = val
                }
            }
        )
    }
}
