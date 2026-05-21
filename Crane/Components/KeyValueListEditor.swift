import SwiftUI

struct KeyValueListEditor<FocusField: Hashable>: View {
    @Binding var entries: [KeyValueEntry]
    let addLabel: LocalizedStringKey
    var focusedField: FocusState<FocusField?>.Binding? = nil
    var keyFieldConstructor: ((UUID) -> FocusField)? = nil
    var valueFieldConstructor: ((UUID) -> FocusField)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(entries) { entry in
                let eb = entryBinding(for: entry.id)
                HStack(spacing: Spacing.sm) {
                    TextField("Key", text: eb.key, prompt: Text("Key"))
                        .focused(focusedField, equals: keyFieldConstructor?(entry.id))
                        .premiumTextFieldStyle()
                        .frame(maxWidth: .infinity)
                    TextField("Value", text: eb.value, prompt: Text("Value"))
                        .focused(focusedField, equals: valueFieldConstructor?(entry.id))
                        .premiumTextFieldStyle()
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
                let entry = KeyValueEntry()
                entries.append(entry)
                if let keyFieldConstructor {
                    focusedField?.wrappedValue = keyFieldConstructor(entry.id)
                }
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

extension View {
    @ViewBuilder
    fileprivate func focused<Value: Hashable>(_ binding: FocusState<Value?>.Binding?, equals value: Value?) -> some View {
        if let binding, let value {
            self.focused(binding, equals: value)
        } else {
            self
        }
    }
}
