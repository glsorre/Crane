//
//  ImagesStore.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 08/12/25.
//

import ContainerClient
import ContainerNetworkService
import ContainerizationOCI
import Foundation
import Combine
import Observation
import SwiftUI

@Observable
class Image : Identifiable, Hashable {
    static func == (lhs: Image, rhs: Image) -> Bool {
        lhs.id == rhs.id
    }
    
    static func == (lhs: Image, rhs: ClientImage) -> Bool {
        lhs.id == rhs.reference
    }
    
    static func == (lhs: ClientImage, rhs: Image) -> Bool {
        lhs.reference == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var id: String
    var image: ClientImage
    var transiting: Bool
    
    init(image: ClientImage) {
        self.id = image.reference
        self.image = image
        self.transiting = false
    }
    
    func update(image: ClientImage) {
        self.image = image
    }
}

@Observable
class ImagesStore {
    static let shared = ImagesStore()
    
    var images: Set<Image> = []
    var imagesTask: Task<Void, Never>? = nil

    var searchText: String = ""
    
    var sortedFilteredImages: [Image] {
        get {
            images
                .sorted { $0.id < $1.id }
                .filter { self.searchText.isEmpty || ($0.id.contains(self.searchText)) }
        }
    }
    
    var containersForImage: [String: [Container]] {
        get {
            Dictionary(grouping: ContainersStore.shared.containers) { $0.container.configuration.image.reference }
        }
    }
    
    private init() {
        self.start()
    }
    
    deinit {
        self.stop()
    }
    
    func stop() {
        self.imagesTask?.cancel()
        self.imagesTask = nil
    }
    
    func start() {
        self.imagesTask = Task {
            while !Task.isCancelled {
                _ = try? await self.collect()
                try? await Task.sleep(for: .seconds(UserDefaults().integer(forKey: "refreshInterval")))
            }
        }
    }
    
    func collect() async throws {
        let currentImages = try await ClientImage.list()
        var currentImagesSet: Set<Image> = Set()
        
        for clientImage in currentImages {
            let newImage = Image(image: clientImage)
            currentImagesSet.insert(newImage)
            if let image = images.first(where: { $0.id == newImage.id }) {
                image.update(image: clientImage)
            }
            images.insert(newImage)
        }
        
        let imagesToRemove = images.subtracting(currentImagesSet)
        imagesToRemove.forEach { imageToRemove in
            images.remove(imageToRemove)
        }
    }
    
    func reset() async throws {
        images.removeAll()
        try await self.collect()
    }
}
