//
//  ImageRowView.swift
//  Crane
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct ImageRowView: View {
    @Environment(\.craneStores) private var stores
    private var containersStore: ContainersStore { stores.containers }
    @State private var isExpanded: Bool = false
    var image: Image

    private var children: [Container] {
        containersStore.containersForImage[image.id] ?? []
    }

    var body: some View {
        Group {
            if children.isEmpty {
                labelRow
            } else {
                DisclosureGroup(isExpanded: $isExpanded) {
                    ForEach(children) { container in
                        AttachedContainerListRow(container: container, detail: nil)
                    }
                } label: {
                    labelRow
                }
            }
        }
    }

    private var labelRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            ResourceListRow(
                title: image.displayName,
                subtitle: subtitle,
                leading: {
                    SwiftUI.Image(systemName: image.isLocalBuild ? "hammer.fill" : "photo.fill")
                        .foregroundStyle(.secondary)
                },
                trailing: {
                    ImagesActionsView(image: image)
                }
            )

            if image.status == .fetching, let progress = image.fetchProgress {
                fetchProgressView(progress: progress)
                    .padding(.leading, 28)
            }
        }
    }

    @ViewBuilder
    private func fetchProgressView(progress: FetchProgress) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let fraction = progress.fraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .controlSize(.small)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .controlSize(.small)
            }

            HStack(spacing: 8) {
                if let bytes = progress.bytesDescription {
                    Text(bytes)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let items = progress.itemsDescription {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(items)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if !progress.subDescription.isEmpty {
                Text(progress.subDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .monospaced()
            }
        }
        .padding(.top, 2)
    }

    private var subtitle: String {
        switch image.status {
        case .fetching:
            return String(localized: "imageStatusFetching")
        case .removing:
            return String(localized: "imageStatusRemoving")
        case .tagging:
            return String(localized: "imageStatusTagging")
        case .available:
            let count = children.count
            if count == 0 {
                return String(localized: "imageStatusReady")
            }
            return count == 1
                ? String(localized: "imageStatusOneContainer")
                : String(format: String(localized: "imageStatusContainers"), count)
        }
    }
}
