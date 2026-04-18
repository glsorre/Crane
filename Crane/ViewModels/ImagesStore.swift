//
//  ImagesStore.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 08/12/25.
//

import ContainerAPIClient
import ContainerResource
import Containerization
import ContainerizationOCI
import Foundation
import Observation
import SwiftUI
import os.log

enum ImageStatus {
    case available
    case fetching
    case removing
    case tagging
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
    
    func setImage(image: ClientImage) async throws {
        self.image = image
        self.imageConfiguration = try? await image.config(for: .current)
    }
    
    func createContainer(id: String, executable: String, arguments: [String], environment: [String], networks: [Network], autoRemove: Bool = true) async throws {
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
        
        let options = ContainerCreateOptions(autoRemove: autoRemove)
        let containerClient = ContainerClient()
        try await containerClient.create(
            configuration: containerConfiguration,
            options: options,
            kernel: try await ClientKernel.getDefaultKernel(for: .current)
        )

        if !autoRemove {
            AppSettings.addPersistentContainerID(id)
        }

        RefreshCoordinator.shared.containerMutated()
    }
}

@Observable
class ImagesStore {
    static let shared = ImagesStore()
    
    var images: Set<Image> = []
    var imagesTask: Task<Void, Never>? = nil
    var resetPolling: (() -> Void)?

    var searchText: String = ""
    
    var sortedFilteredImages: [Image] {
        images
            .sorted { $0.id < $1.id }
            .filter { self.searchText.isEmpty || ($0.id.contains(self.searchText)) }
    }
    
    private init() {
        self.start()
    }
    
    deinit {
        self.stop()
    }
    
    func stop() {
        self.imagesTask?.cancel()
    }

    func start() {
        guard AppSettings.autoRefresh else { return }
        let (task, reset) = startAdaptivePolling(
            baseInterval: { AppSettings.refreshInterval },
            maxInterval: { AppSettings.maxPollingInterval }
        ) {
            try await self.collectWithChangeDetection()
        }
        self.imagesTask = task
        self.resetPolling = reset
    }

    func fetchImage(reference: String) async throws {
        let normalizedReference = try ClientImage.normalizeReference(reference)
        let image = Image(id: normalizedReference)
        self.images.insert(image)
        let clientImage = try await ClientImage.fetch(reference: reference)
        try await image.setImage(image: clientImage)
        image.status = .available
        images.update(with: image)
        RefreshCoordinator.shared.imageMutated()
    }

    func removeImage(reference: String) async throws {
        if let existingImage = self.images.first(where: { $0.id == reference }) {
            existingImage.status = .removing
            try await existingImage.remove()
            images.remove(existingImage)
        }
        RefreshCoordinator.shared.imageMutated()
    }

    /// Adds another OCI reference pointing at the same image (`container image tag <source> <target>`).
    @discardableResult
    func tagImage(sourceReference: String, newReference: String) async -> Bool {
        await applyTagOrRename(sourceReference: sourceReference, newReference: newReference, deleteSourceAfter: false)
    }

    /// Tags with a new reference then removes the old reference (containers still using the old name are unchanged).
    @discardableResult
    func renameImage(sourceReference: String, newReference: String) async -> Bool {
        await applyTagOrRename(sourceReference: sourceReference, newReference: newReference, deleteSourceAfter: true)
    }

    private func applyTagOrRename(sourceReference: String, newReference: String, deleteSourceAfter: Bool) async -> Bool {
        guard let image = images.first(where: { $0.id == sourceReference }) else { return false }
        guard let clientImage = image.image else {
            AppViewModel.shared.showError(.imageTagFailed(String(localized: "imageTagClientMissing")))
            return false
        }
        guard image.status == .available else { return false }

        let normalizedNew: String
        do {
            normalizedNew = try ClientImage.normalizeReference(newReference)
        } catch {
            AppViewModel.shared.showError(.imageTagFailed(error.localizedDescription))
            return false
        }

        let normalizedSource: String
        do {
            normalizedSource = try ClientImage.normalizeReference(sourceReference)
        } catch {
            AppViewModel.shared.showError(.imageTagFailed(error.localizedDescription))
            return false
        }

        guard normalizedNew != normalizedSource else {
            AppViewModel.shared.showError(.imageTagFailed(String(localized: "imageTagSameReference")))
            return false
        }

        image.status = .tagging
        defer { image.status = .available }

        do {
            _ = try await clientImage.tag(new: normalizedNew)
            if deleteSourceAfter {
                try await ClientImage.delete(reference: normalizedSource)
            }
            try? await collect()
            RefreshCoordinator.shared.imageMutated()
            return true
        } catch {
            if deleteSourceAfter {
                AppViewModel.shared.showError(.imageRenameFailed(error.localizedDescription))
            } else {
                AppViewModel.shared.showError(.imageTagFailed(error.localizedDescription))
            }
            return false
        }
    }

    @discardableResult
    func collect() async throws -> Bool {
        try await collectWithChangeDetection()
    }

    private func collectWithChangeDetection() async throws -> Bool {
        let previousIDs = Set(images.map { $0.id })

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

        let newIDs = Set(images.map { $0.id })
        return previousIDs != newIDs
    }
    
    func reset() async throws {
        images.removeAll()
        try await self.collect()
    }
}

