//
//  MainListEmptyState.swift
//  Crane
//

import SwiftUI

struct MainListEmptyState: View {
    var searchText: String
    var emptyTitle: LocalizedStringKey
    var emptyDescription: LocalizedStringKey
    var systemImage: String

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                // Soft glow background behind the icon
                Circle()
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 80, height: 80)
                    .blur(radius: 3)

                SwiftUI.Image(systemName: isSearching ? "magnifyingglass" : systemImage)
                    .font(.system(size: 38))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.bottom, Spacing.xs)

            Text(isSearching ? "listSearchNoResultsTitle" : emptyTitle)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(isSearching ? "listSearchNoResultsDescription" : emptyDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 280)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
