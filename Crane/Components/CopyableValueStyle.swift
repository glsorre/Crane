//
//  CopyableValueStyle.swift
//  Crane
//

import SwiftUI

struct CopyButton: View {
    let text: String
    @State private var showCheck = false

    var body: some View {
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            showCheck = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showCheck = false
            }
        }) {
            SwiftUI.Image(systemName: showCheck ? "checkmark" : "doc.on.doc")
                .font(.caption)
                .foregroundStyle(showCheck ? .green : .secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.borderless)
    }
}

struct CopyableValueStyle: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(.vertical, Spacing.xxs)
            .padding(.horizontal, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? .thickMaterial : .regularMaterial)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func copyableValueStyle() -> some View {
        modifier(CopyableValueStyle())
    }
}
