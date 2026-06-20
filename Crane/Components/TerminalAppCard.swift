//
//  TerminalAppCard.swift
//  Crane
//
//  Card-style picker entry for a `TerminalApp`. Tries to load the real app icon
//  via `NSWorkspace`; if unavailable (system default, custom, or app not
//  installed) it falls back to a curated SF Symbol.
//

import AppKit
import SwiftUI

struct TerminalAppCard: View {
    let app: TerminalApp
    let isSelected: Bool
    let onSelect: () -> Void

    private static let iconSize: CGFloat = 48

    var body: some View {
        button
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help(String(format: String(localized: "terminalCardHelp"), app.displayName))
            .accessibilityLabel(app.displayName)
            .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var button: some View {
        Button(action: onSelect) { cardContent }
    }

    private var cardContent: some View {
        VStack(spacing: Spacing.xs) {
            iconView
                .frame(width: Self.iconSize, height: Self.iconSize)
            nameLabel
            customBadge
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.xs)
        .background(cardBackground)
        .overlay(cardBorder)
        .overlay(alignment: .topTrailing) {
            selectedCheckmark
        }
    }

    private var nameLabel: some View {
        Text(app.displayName)
            .font(.callout)
            .fontWeight(.medium)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    @ViewBuilder
    private var customBadge: some View {
        if app == .custom {
            Text("terminalCustomBadge")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(Color.secondary.opacity(0.12))
                )
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(
                isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                lineWidth: isSelected ? 2 : 1
            )
    }

    @ViewBuilder
    private var selectedCheckmark: some View {
        if isSelected {
            SwiftUI.Image(systemName: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.tint)
                .padding(6)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let nsImage = liveAppIconImage() {
            SwiftUI.Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            SwiftUI.Image(systemName: TerminalIconFallback.symbol(for: app))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(6)
                .foregroundStyle(.tint)
        }
    }

    /// Returns the real installed app icon, or `nil` for cases where no bundle
    /// is associated (system default, custom) or where the app isn't installed.
    private func liveAppIconImage() -> NSImage? {
        guard let appURL = TerminalLauncher.appURL(for: app) else { return nil }
        // `NSWorkspace.icon(forFile:)` returns a generic icon even for missing
        // files. Use the file's existence to avoid the generic placeholder.
        guard FileManager.default.fileExists(atPath: appURL.path) else { return nil }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
}
