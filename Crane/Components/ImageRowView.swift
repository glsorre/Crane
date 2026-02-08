//
//  ImageRowView.swift
//  Crane
//

import ContainerAPIClient
import ContainerResource
import SwiftUI

struct ImageRowView: View {
    @State private var appViewModel = AppViewModel.shared
    @State private var containersStore = ContainersStore.shared
    @State private var isExpanded: Bool = true
    var image: Image

    private var children: [Container] {
        containersStore.containersForImage[image.id] ?? []
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(children) { container in
                HStack {
                    Circle()
                        .fill(container.isExited ? .secondary : container.container.status.getColor())
                        .frame(width: 8, height: 8)

                    Text(container.id)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    ContainerActionsView(id: container.id)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    appViewModel.navigateTo(to: .detail(container: container))
                }
            }
        } label: {
            HStack {
                SwiftUI.Image(systemName: "photo.fill")
                    .foregroundStyle(.secondary)

                Text(image.id)
                    .font(.headline)

                Spacer()

                ImagesActionsView(image: image)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }
}
