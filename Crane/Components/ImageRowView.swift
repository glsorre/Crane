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
        .padding(.vertical, Spacing.xxs)
    }

    private var labelRow: some View {
        HStack {
            SwiftUI.Image(systemName: "photo.fill")
                .foregroundStyle(.secondary)

            Text(image.id)
                .font(.headline)

            Spacer()

            ImagesActionsView(image: image)
        }
    }
}
