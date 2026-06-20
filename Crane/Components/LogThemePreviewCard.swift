//
//  LogThemePreviewCard.swift
//  Crane
//
//  Visual preview card for a `LogTheme`. Renders a miniature "code window"
//  with a window-chrome header (traffic-light dots + theme name) and a
//  preview area showing sample log lines colored by the theme's palette.
//  Used by the in-app Settings page.
//

import SwiftUI

struct LogThemePreviewCard: View {
    let theme: LogTheme
    let palette: LogThemePalette
    let isSelected: Bool
    let onSelect: () -> Void

    private static let cardWidth: CGFloat = 240
    private static let cardHeight: CGFloat = 130
    private static let headerHeight: CGFloat = 24

    /// Levels rendered as swatches in left-to-right order. `.none` falls back to
    /// `.info` inside `LogThemePalette.color(for:)`, so it is not its own chip.
    private static let previewLevels: [LogLevel] = [.fatal, .error, .warn, .info, .debug, .trace]

    /// Sample log lines that exercise every level. Kept short so the card
    /// reads at a glance — this is a theme preview, not real log output.
    /// Messages are short enough to fit on a single line at 9pt monospaced
    /// inside the 220pt content width (timestamp + level + message).
    private static let sampleLines: [SampleLogLine] = [
        SampleLogLine(level: .info, message: "container started"),
        SampleLogLine(level: .debug, message: "polling endpoint"),
        SampleLogLine(level: .warn, message: "retry 1/3"),
        SampleLogLine(level: .error, message: "conn refused")
    ]

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                header
                previewArea
            }
            .frame(width: Self.cardWidth, height: Self.cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(cardBorder)
            .shadow(
                color: Color.accentColor.opacity(isSelected ? 0.22 : 0),
                radius: isSelected ? 8 : 0,
                x: 0,
                y: 0
            )
            .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .help(String(format: String(localized: "logThemeCardAria"), theme.displayName))
        .accessibilityLabel(theme.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - Subviews

    /// Header: centred theme name with an optional selection checkmark on
    /// the right. Rendered as a slightly different shade of the theme
    /// background so it reads as a distinct title bar on both light and
    /// dark themes.
    private var header: some View {
        ZStack {
            Text(theme.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(headerTextColor)
                .lineLimit(1)
                .padding(.horizontal, 10)

            selectionCheck
        }
        .frame(height: Self.headerHeight)
        .background(headerBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(separatorColor)
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var selectionCheck: some View {
        if isSelected {
            HStack {
                Spacer()
                SwiftUI.Image(systemName: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 0.5)
            }
            .padding(.trailing, 8)
        }
    }

    /// Preview area: 4 sample log lines rendered in the theme's actual
    /// colours, on top of the theme background. The line spacing and
    /// font size are tuned so all four lines plus the swatch row fit
    /// cleanly without leaving dead white space at the bottom.
    private var previewArea: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(Self.sampleLines.enumerated()), id: \.offset) { index, line in
                sampleLineView(line, index: index)
            }
            Spacer(minLength: 0)
            swatchRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 10)
        .padding(.top, 7)
        .padding(.bottom, 7)
        .background(Color(nsColor: palette.background))
    }

    private func sampleLineView(_ line: SampleLogLine, index: Int) -> some View {
        HStack(spacing: 5) {
            Text("12:34:5\(6 + index)")
                .foregroundStyle(dimTextColor)
            Text(line.level.rawValue.padding(toLength: 5, withPad: " ", startingAt: 0))
                .foregroundStyle(Color(nsColor: palette.color(for: line.level)))
                .fontWeight(.semibold)
            Text(line.message)
                .foregroundStyle(Color(nsColor: palette.info))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.system(size: 9, design: .monospaced))
    }

    /// Slim row of level swatches at the bottom of the preview area so
    /// users can compare every level at a glance, not just the four lines.
    private var swatchRow: some View {
        HStack(spacing: 4) {
            ForEach(Self.previewLevels, id: \.self) { level in
                Circle()
                    .fill(Color(nsColor: palette.color(for: level)))
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
            }
        }
    }

    // MARK: - Styling helpers

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 1)
    }

    private var borderColor: Color {
        if isSelected { return .accentColor }
        if isHovered { return .secondary.opacity(0.4) }
        return .secondary.opacity(0.25)
    }

    /// True when the theme background is dark enough that light text reads
    /// better. Uses WCAG-style relative luminance so the decision is stable
    /// regardless of the system appearance.
    private var backgroundIsDark: Bool {
        let bg = palette.background.usingColorSpace(.sRGB) ?? palette.background
        let luminance = 0.2126 * bg.redComponent + 0.7152 * bg.greenComponent + 0.0722 * bg.blueComponent
        return luminance < 0.5
    }

    /// Header background: a small shift away from the preview background
    /// so the title bar reads as a distinct band on both light and dark
    /// themes. Dark themes get a lighter bar, light themes get a darker one.
    private var headerBackground: Color {
        let bg = palette.background.usingColorSpace(.sRGB) ?? palette.background
        if backgroundIsDark {
            return Color(
                red: min(bg.redComponent + 0.07, 1),
                green: min(bg.greenComponent + 0.07, 1),
                blue: min(bg.blueComponent + 0.07, 1)
            )
        }
        return Color(
            red: max(bg.redComponent - 0.04, 0),
            green: max(bg.greenComponent - 0.04, 0),
            blue: max(bg.blueComponent - 0.04, 0)
        )
    }

    private var headerTextColor: Color {
        backgroundIsDark ? .white.opacity(0.9) : .black.opacity(0.75)
    }

    private var dimTextColor: Color {
        backgroundIsDark ? .white.opacity(0.4) : .black.opacity(0.4)
    }

    private var separatorColor: Color {
        backgroundIsDark ? .white.opacity(0.08) : .black.opacity(0.08)
    }
}

/// One rendered log line in the theme preview. Defined locally so the
/// preview card doesn't depend on the real `ContainerLogLine` model.
private struct SampleLogLine {
    let level: LogLevel
    let message: String
}
