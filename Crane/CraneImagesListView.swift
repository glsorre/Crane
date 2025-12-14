//
//  CraneImagesListView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerClient
import ContainerNetworkService
import SwiftUI
import Combine

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
    
    @State private var fetchingPopupIsVisible: Bool = false
    @State private var imageToFetch: String = ""
    
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
        buildTable(images: imagesStore.sortedFilteredImages)
            .tableStyle(.inset)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    VStack(spacing: 20) {
                        Button(action: {
                            fetchingPopupIsVisible.toggle()
                        }) {
                            SwiftUI.Image(systemName: "plus")
                        }
                        .buttonStyle(.bordered)
                        .popover(isPresented: $fetchingPopupIsVisible) {
                            Form {
                                TextField(String(localized: "fetchImageUrl"), text: $imageToFetch)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                Button(action: {
                                    Task {
                                        do {
                                            fetchingPopupIsVisible.toggle()
                                            try await imagesStore.fetchImage(reference: imageToFetch)
                                        } catch {
                                            print("Error fetching image: \(error)")
                                        }
                                    }
                                }) {
                                    Text(String(localized: "fetchImage"))
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                                .disabled(imageToFetch.isEmpty)
                            }
                            .frame(width: 400)
                            .padding()
                        }
                    }
                }
            }
            .searchable(text: $imagesStore.searchText, placement: .toolbar)
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
    
    private func buildTable(images: [Image]) -> some View {
        Table(of: ImageListItem.self, selection: $selection) {
            TableColumn("name") { item in
                switch item {
                case .image(let image):
                    Label(image.id, systemImage: "photo.fill")
                        .padding(5)
                case .container(let container, _):
                    Text(container.id)
                        .padding(5)
                        .foregroundColor(.secondary)
                }
            }
            TableColumn("") { item in
                switch item {
                case .image(let image):
                    ImagesActionsView(image: image)
                case .container(let container, _):
                    ContainerActionsView(id: container.id)
                }
            }
            .width(105)
        } rows: {
            ForEach(images) { key in
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
    }
}
