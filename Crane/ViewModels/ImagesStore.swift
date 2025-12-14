//
//  ImagesStore.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 08/12/25.
//

import ContainerClient
import ContainerNetworkService
import Containerization
import ContainerizationOCI
import Foundation
import Combine
import Observation
import SwiftUI

enum ImageStatus {
    case available
    case fetching
    case removing
}

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
    var image: ClientImage?
    var imageConfiguration: ContainerizationOCI.Image?
    var status: ImageStatus
    
    init(id: String) {
        self.id = id
        self.status = .fetching
    }
    
    init(image: ClientImage) {
        self.id = image.reference
        self.image = image
        self.status = .available
    }
    
    func remove() async throws {
        try await ClientImage.delete(reference: self.id)
    }
    
    func setImage(image: ClientImage) async throws{
        self.image = image
    }
    
    func createContainer(id: String, executable: String, arguments: [String], environment: [String], networks: [Network]) async throws {
        let processConfiguration: ProcessConfiguration = ProcessConfiguration(
            executable: executable,
            arguments: arguments,
            environment: environment,
        )
        
        
        var containerConfiguration = ContainerConfiguration(
            id: id,
            image: image!.description,
            process: processConfiguration,
        )
        
        containerConfiguration.networks = networks.map { network in
            AttachmentConfiguration(network: network.id, options: AttachmentOptions(hostname: network.id))
        }
        
        let clientContainer = try await ClientContainer.create(
            configuration: containerConfiguration,
            options: .default,
            kernel: ClientKernel.getDefaultKernel(for: .current)
        )
        
        let container = Container(container: clientContainer)
        ContainersStore.shared.containers.insert(container)
        container.update(container: clientContainer)
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
    
    func fetchImage(reference: String) async throws {
        let normalizedReference = try ClientImage.normalizeReference(reference)
        let image = Image(id: normalizedReference)
        self.images.insert(image)
        let clientImage = try await ClientImage.fetch(reference: reference)
        try await image.setImage(image: clientImage)
        image.status = .available
        images.update(with: image)
    }
    
    func removeImage(reference: String) async throws {
        if let existingImage = self.images.first(where: { $0.id == reference }) {
            existingImage.status = .removing
            try await existingImage.remove()
            images.remove(existingImage)
        }
    }
    
    func collect() async throws {
        let currentImages = try await ClientImage.list()
        var currentImagesSet: Set<Image> = Set()
        
        for clientImage in currentImages {
            let newImage = Image(image: clientImage)
            currentImagesSet.insert(newImage)
            if let image = images.first(where: { $0.id == newImage.id }) {
                try await image.setImage(image: clientImage)
            }
            images.insert(newImage)
        }
        
        let imagesToRemove = images.subtracting(currentImagesSet)
        imagesToRemove.forEach { imageToRemove in
            if imageToRemove.status != .fetching {
                images.remove(imageToRemove)
            }
        }
    }
    
    func reset() async throws {
        images.removeAll()
        try await self.collect()
    }
}

