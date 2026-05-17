//
//  RowActionButton.swift
//  Crane
//

import SwiftUI

enum RowActionVariant {
    case primary       // .glassProminent — main affordance (run, start)
    case secondary     // .glass — neutral secondary (restart)
    case destructive   // .glass with red tint (trash)
    case tertiary      // .borderless secondary (shell, tag, dismiss)
}

/// Unified trailing-zone action button for resource rows.
/// Wraps `SpinnerButton` so any variant can swap to a spinner while `isLoading`.
struct RowActionButton<Label: View>: View {
    let variant: RowActionVariant
    let isLoading: Bool
    let isEnabled: Bool
    let help: String?
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    init(
        _ variant: RowActionVariant,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        help: String? = nil,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.variant = variant
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.help = help
        self.action = action
        self.label = label
    }

    var body: some View {
        applyStyle(
            SpinnerButton(isLoading: isLoading, action: action) {
                applyLabelStyle(label())
            }
        )
        .frame(width: 50)
        .disabled(!isEnabled)
        .ifLet(help) { view, helpText in
            view.help(helpText).accessibilityLabel(helpText)
        }
    }

    @ViewBuilder
    private func applyStyle<V: View>(_ view: V) -> some View {
        switch variant {
        case .primary:
            view.buttonStyle(.glassProminent)
        case .secondary:
            view.buttonStyle(.glass)
        case .destructive:
            view.buttonStyle(.glass)
                .foregroundColor(Color(.systemRed))
        case .tertiary:
            view.buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private func applyLabelStyle<V: View>(_ label: V) -> some View {
        switch variant {
        case .tertiary:
            label
                .font(Font.system(size: 11))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
        default:
            label.font(Font.system(size: 11))
        }
    }
}

private extension View {
    @ViewBuilder
    func ifLet<T, Transform: View>(
        _ value: T?,
        transform: (Self, T) -> Transform
    ) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}
