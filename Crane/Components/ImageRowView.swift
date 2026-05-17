//
//  ImageRowView.swift
//  Crane
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct ImageRowView: View {
    @State private var containersStore = ContainersStore.shared
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
