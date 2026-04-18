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
        if isSearching {
            ContentUnavailableView(
                "listSearchNoResultsTitle",
                systemImage: "magnifyingglass",
                description: Text("listSearchNoResultsDescription")
            )
        } else {
            ContentUnavailableView(
                emptyTitle,
                systemImage: systemImage,
                description: Text(emptyDescription)
            )
        }
    }
}
