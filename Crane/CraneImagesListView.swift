//
//  CraneImagesListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import SwiftUI

struct CraneImagesListView: View {
    @Environment(\.craneStores) private var stores
    private var imagesStore: ImagesStore { stores.images }
    private var buildViewModel: BuildViewModel { stores.build }

    @State private var fetchSheetIsVisible = false
    @State private var buildSheetIsVisible = false

    private var listItems: [Image] {
        imagesStore.sortedFilteredImages
    }

    private var showsBuildPlaceholder: Bool {
        buildViewModel.status != .idle
    }

    var body: some View {
        ZStack {
            List {
                if showsBuildPlaceholder {
                    BuildPlaceholderRow(viewModel: buildViewModel)
                }
                ForEach(listItems, id: \.objectIdentity) { image in
                    ImageRowView(image: image)
                }
            }
            .listStyle(.inset)
            .contentMargins(.top, Spacing.lg, for: .scrollContent)

            if listItems.isEmpty && !showsBuildPlaceholder {
                MainListEmptyState(
                    searchText: imagesStore.searchText,
                    emptyTitle: "listEmptyImagesTitle",
                    emptyDescription: "listEmptyImagesDescription",
                    systemImage: "photo"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(
                    action: { buildSheetIsVisible.toggle() },
                    label: { SwiftUI.Image(systemName: "hammer.fill") }
                )
                .buttonStyle(.glass)
                .disabled(buildViewModel.status.isBuilding)
                .help(String(localized: "toolbarHelpBuildImage"))
                .accessibilityLabel(String(localized: "toolbarHelpBuildImage"))
            }
            ToolbarItem(placement: .navigation) {
                Button(
                    action: { fetchSheetIsVisible = true },
                    label: { SwiftUI.Image(systemName: "plus") }
                )
                .buttonStyle(.glassProminent)
                .help(String(localized: "toolbarHelpFetchImage"))
                .accessibilityLabel(String(localized: "toolbarHelpFetchImage"))
            }
        }
        .sheet(isPresented: $fetchSheetIsVisible) {
            ImageFetchView(isPresented: $fetchSheetIsVisible)
        }
        .sheet(isPresented: $buildSheetIsVisible) {
            ImageBuildView(isPresented: $buildSheetIsVisible)
        }
    }
}

/// In-list row that mirrors a regular image row while a build is running, succeeding, or failing.
/// Replaces the former BuildBannerView so the Images tab shape matches Networks/Volumes/Containers.
private struct BuildPlaceholderRow: View {
    let viewModel: BuildViewModel

    var body: some View {
        ResourceListRow(
            title: viewModel.currentBuildTag ?? String(localized: "buildPlaceholderTitle"),
            subtitle: subtitle,
            leading: {
                leadingIcon
            },
            trailing: {
                trailingControl
            }
        )
    }

    @ViewBuilder
    private var leadingIcon: some View {
        switch viewModel.status {
        case .success:
            SwiftUI.Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            SwiftUI.Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        default:
            SwiftUI.Image(systemName: "hammer.fill")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        switch viewModel.status {
        case .startingBuilder, .building, .unpacking:
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
        case .failed:
            RowActionButton(
                .tertiary,
                action: { viewModel.dismissTerminalStatus() },
                label: {
                    SwiftUI.Image(systemName: "xmark")
                }
            )
        default:
            EmptyView()
        }
    }

    private var subtitle: String {
        switch viewModel.status {
        case .idle:
            return ""
        case .startingBuilder:
            return String(localized: "buildStarting")
        case .building:
            return String(localized: "buildInProgress")
        case .unpacking:
            return String(localized: "buildUnpacking")
        case .success:
            return String(localized: "buildSuccess")
        case .failed(let message):
            return message
        }
    }
}
