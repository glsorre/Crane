//
//  CraneNetworksListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerClient
import ContainerNetworkService
import SwiftUI

enum ImageListItem {
    case image(ClientImage)
    case container(ClientContainer, imageKey: String)
    
    static var sortOrderComparator: KeyPathComparator<ImageListItem> {
        .init(\.id, order: .forward)
    }
    
    var id: String {
        switch self {
        case .image(let image):
            return image.reference
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
    @Bindable var viewModel: CraneViewModel
    @State private var selection: ImageListItem.ID? = nil
    @State private var expandedImages: [String: Bool] = [:]
    
    private var allSortedImages: [(String, [ClientContainer])] {
        return viewModel.containersForImage.sorted { $0.key < $1.key }
    }
    
    private var sortedFilteredImages: [(String, [ClientContainer])] {
        let searchText = viewModel.searchText
        if searchText.isEmpty {
            return allSortedImages
        } else {
            return allSortedImages.filter { key, _ in
                key.contains(searchText)
            }
        }
    }
    
    private func imageForKey(_ key: String) -> ImageListItem? {
        guard let image = viewModel.images![key] else {
            return nil
        }
        return .image(image)
    }
    
    private func childrenForImage(_ key: String) -> [ImageListItem] {
        let containers = viewModel.containersForImage[key] ?? []
        return containers.map { .container($0, imageKey: key) }
    }
    
    private func itemForID(_ id: ImageListItem.ID?) -> ImageListItem? {
        guard let id = id else { return nil }
        for (key, containers) in viewModel.containersForImage{
            if let image = viewModel.images?[key], image.reference == id {
                return .image(image)
            }
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
                    Label(image.reference, systemImage: "photo.circle.fill")
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
                    ContainerListActionsView(viewModel: viewModel, id: container.id)
                }
            }
            .width(100)
        } rows: {
            ForEach(sortedFilteredImages, id: \.0) { imageKey, _ in
                if let imageItem = imageForKey(imageKey) {
                    let childrenItems = childrenForImage(imageKey)
                    
                    let isExpanded = expandedImages[imageKey, default: true]
                    DisclosureTableRow(imageItem, isExpanded: Binding(
                        get: { isExpanded },
                        set: { expandedImages[imageKey] = $0 }
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
                    viewModel.path.append(CraneRoute.detail(id: container.id))
                }
            }
        }
    }
}

