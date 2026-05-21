//
//  PremiumTextField.swift
//  Crane
//

import SwiftUI

#if os(macOS)
import AppKit
#endif

// MARK: - Premium TextField Modifier (auto-tracks focus)

struct PremiumTextFieldModifier: ViewModifier {
    var isError: Bool

    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .labelsHidden()
            .multilineTextAlignment(.leading)
            .environment(\.layoutDirection, .leftToRight)
            .focused($isFocused)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isError ? Color.red : (isFocused ? Color.accentColor : Color(NSColor.separatorColor)),
                        lineWidth: isError || isFocused ? 1.5 : 0.5
                    )
            )
            .shadow(
                color: isError ? Color.red.opacity(0.18) : (isFocused ? Color.accentColor.opacity(0.18) : Color.clear),
                radius: 4,
                x: 0,
                y: 0
            )
            .scaleEffect(isFocused ? 1.005 : 1.0)
            .animation(.spring(duration: 0.2), value: isFocused)
            .animation(.spring(duration: 0.2), value: isError)
    }
}

// MARK: - View Extension

extension View {
    /// Applies the premium text field style with automatic focus tracking.
    func premiumTextFieldStyle(isError: Bool = false) -> some View {
        self.modifier(PremiumTextFieldModifier(isError: isError))
    }

    /// Legacy two-parameter overload — `isFocused` is ignored (tracked automatically).
    @available(*, deprecated, message: "Use premiumTextFieldStyle(isError:) — focus is now tracked automatically.")
    func premiumTextFieldStyle(isFocused: Bool, isError: Bool) -> some View {
        self.modifier(PremiumTextFieldModifier(isError: isError))
    }
}
