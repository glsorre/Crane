//
//  ResourceListRow.swift
//  Crane
//

import SwiftUI

/// Shared skeleton for the four resource lists (containers, images, networks, volumes).
/// Fixes the leading icon zone, headline title, optional secondary subtitle, and trailing action zone
/// so every tab has the same row rhythm.
struct ResourceListRow<Leading: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            leading()
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Spacing.sm)

            trailing()
        }
        .padding(.vertical, Spacing.xxs)
    }
}
