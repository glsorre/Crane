//
//  CraneImagesListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerClient
import ContainerNetworkService
import SwiftUI

enum ImageListItem {
    case image(Image)
    case container(Container, imageKey: String)
    
    static var sortOrderComparator: KeyPathComparator<ImageListItem> {
        .init(\.id, order: .forward)
    }
    
    var id: String {
        switch self {
        case .image(let image):
            return image.id
        case .container(let container, let imageKey):
            return "\(container.id)-\(imageKey)"
        }
    }
}

extension ImageListItem: Identifiable {}

extension ImageListItem: Hashable {
    static func == (lhs: ImageListItem, rhs: ImageListItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct CraneImagesListView: View {
    @State private var appViewModel = AppViewModel.shared
    @State private var imagesStore = ImagesStore.shared
    @State private var selection: ImageListItem.ID? = nil
    @State private var expandedImages: [String: Bool] = [:]
    
    private func imageForKey(_ key: String) -> ImageListItem? {
        guard let image = imagesStore.images.first(where: { $0.id == key }) else {
            return nil
        }
        return .image(image)
    }
    
    private func childrenForImage(_ key: String) -> [ImageListItem] {
        let containers = imagesStore.containersForImage[key] ?? []
        return containers.map { .container($0, imageKey: key) }
    }
    
    private func itemForID(_ id: ImageListItem.ID?) -> ImageListItem? {
        guard let id = id else { return nil }
        for image in imagesStore.images {
            if image.id == id {
                return .image(image)
            }
        }
        for (key, containers) in imagesStore.containersForImage {
            for container in containers {
                if "\(container.id)-\(key)" == id {
                    return .container(container, imageKey: key)
                }
            }
        }
        return nil
    }
    
    var body: some View {
        Table(of: ImageListItem.self, selection: $selection) {
            TableColumn("name") { item in
                switch item {
                case .image(let image):
                    Label(image.id, systemImage: "photo.circle.fill")
                        .padding(5)
                case .container(let container, _):
                    Text(container.id)
                        .padding(5)
                        .foregroundColor(.secondary)
                }
            }
            TableColumn("") { item in
                switch item {
                case .image:
                    EmptyView()
                case .container(let container, _):
                    ContainerListActionsView(id: container.id)
                }
            }
            .width(100)
        } rows: {
            ForEach(imagesStore.sortedFilteredImages) { key in
                if let imageItem = imageForKey(key.id) {
                    let childrenItems = childrenForImage(key.id)
                    
                    let isExpanded = expandedImages[key.id, default: true]
                    DisclosureTableRow(imageItem, isExpanded: Binding(
                        get: { isExpanded },
                        set: { expandedImages[key.id] = $0 }
                    )) {
                        ForEach(childrenItems, id: \.id) { childItem in
                            TableRow(childItem)
                        }
                    }
                }
            }
        }
        .tableStyle(.inset)
        .onChange(of: selection) { _, newValue in
            if let item = itemForID(newValue) {
                switch item {
                case .image:
                    selection = nil
                case .container(let container, _):
                    selection = nil
                    appViewModel.navigateTo(to: .detail(container: container))
                }
            }
        }
    }
}
