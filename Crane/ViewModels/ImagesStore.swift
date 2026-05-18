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

struct ImageTagError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@Observable
class Image: Identifiable, Hashable {
    /// OCI label key written by `BuildViewModel` onto images built locally via Crane's hammer flow.
    static let localBuildLabelKey = "me.rightright.crane.local-build"

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
    var objectIdentity: ObjectIdentifier { ObjectIdentifier(self) }
    var status: ImageStatus
    var fetchProgress: FetchProgress?

    var isLocalBuild: Bool {
        imageConfiguration?.config?.labels?[Self.localBuildLabelKey] == "true"
    }

    /// Title to render in lists for this image. Strips the default `docker.io/library/` registry prefix only for locally-built images so the hammer-marked row reads cleanly; pulled images keep the full ref so origin stays visible.
    var displayName: String {
        guard isLocalBuild else { return id }
        let prefix = "docker.io/library/"
        return id.hasPrefix(prefix) ? String(id.dropFirst(prefix.count)) : id
    }

    init(id: String) {
        self.id = id
        self.status = .fetching
        self.fetchProgress = FetchProgress()
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
        do {
            self.imageConfiguration = try await image.config(for: .current)
        } catch {
            self.imageConfiguration = nil
            Log.images.error(
                "config(for: .current) failed for \(self.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func createContainer(
        id: String, executable: String, arguments: [String], environment: [String], networks: [Network], autoRemove: Bool = true
    ) async throws {
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

        CraneMutationBus.postContainerMutated()
    }
}

@Observable
class ImagesStore {
    private let onError: @MainActor (CraneError) -> Void
    private let tracker: ConnectionHealthTracker?

    var images: Set<Image> = []
    var imagesTask: Task<Void, Never>?
    var resetPolling: (() -> Void)?

    var searchText: String = ""

    var sortedFilteredImages: [Image] {
        images
            .sorted { $0.id < $1.id }
            .filter { self.searchText.isEmpty || ($0.id.contains(self.searchText)) }
    }

    init(
        onError: @escaping @MainActor (CraneError) -> Void = { _ in },
        tracker: ConnectionHealthTracker? = nil
    ) {
        self.onError = onError
        self.tracker = tracker
    }

    deinit {
        self.stop()
    }

    func stop() {
        self.imagesTask?.cancel()
    }

    func start() {
        guard AppSettings.autoRefresh else { return }
        let tracker = self.tracker
        let (task, reset) = startAdaptivePolling(
            baseInterval: { AppSettings.refreshInterval },
            maxInterval: { AppSettings.maxPollingInterval },
            isVisible: { PollingVisibility.isVisible(for: .images) },
            onError: { error in
                Task { @MainActor in
                    tracker?.recordFailure(resource: .images, error: error)
                }
            },
            work: {
                try await self.collectWithChangeDetection()
            }
        )
        self.imagesTask = task
        self.resetPolling = reset
    }

    func fetchImage(reference: String) async throws {
        let normalizedReference = try ClientImage.normalizeReference(reference)
        let image = Image(id: normalizedReference)
        self.images.insert(image)
        let progress = image.fetchProgress
        Task {
            do {
                let clientImage = try await ClientImage.fetch(
                    reference: reference,
                    progressUpdate: { events in
                        await MainActor.run {
                            progress?.apply(events)
                        }
                    }
                )
                try await image.setImage(image: clientImage)
                image.fetchProgress = nil
                image.status = .available
                images.update(with: image)
                CraneMutationBus.postImageMutated()
            } catch {
                images.remove(image)
                Log.images.error("fetchImage failed for \(normalizedReference): \(error.localizedDescription, privacy: .public)")
                await onError(.imageFetchFailed(underlying: error))
            }
        }
    }

    func removeImage(reference: String) async throws {
        if let existingImage = self.images.first(where: { $0.id == reference }) {
            existingImage.status = .removing
            do {
                try await existingImage.remove()
                images.remove(existingImage)
            } catch {
                existingImage.status = .available
                Log.images.error("removeImage failed: \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }
        CraneMutationBus.postImageMutated()
    }

    /// Adds another OCI reference pointing at the same image (`container image tag <source> <target>`).
    func tagImage(sourceReference: String, newReference: String) async throws {
        try await applyTagOrRename(sourceReference: sourceReference, newReference: newReference, deleteSourceAfter: false)
    }

    /// Tags with a new reference then removes the old reference (containers still using the old name are unchanged).
    func renameImage(sourceReference: String, newReference: String) async throws {
        try await applyTagOrRename(sourceReference: sourceReference, newReference: newReference, deleteSourceAfter: true)
    }

    private func applyTagOrRename(sourceReference: String, newReference: String, deleteSourceAfter: Bool) async throws {
        guard let image = images.first(where: { $0.id == sourceReference }) else {
            throw ImageTagError(message: String(localized: "imageTagClientMissing"))
        }
        guard let clientImage = image.image else {
            throw ImageTagError(message: String(localized: "imageTagClientMissing"))
        }
        guard image.status == .available else {
            throw ImageTagError(message: String(localized: "imageTagClientMissing"))
        }

        let normalizedNew = try ClientImage.normalizeReference(newReference)
        let normalizedSource = try ClientImage.normalizeReference(sourceReference)

        guard normalizedNew != normalizedSource else {
            throw ImageTagError(message: String(localized: "imageTagSameReference"))
        }

        image.status = .tagging
        defer { image.status = .available }

        do {
            _ = try await clientImage.tag(new: normalizedNew)
            if deleteSourceAfter {
                try await ClientImage.delete(reference: normalizedSource)
            }
        } catch {
            Log.images.error("applyTagOrRename failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        _ = try? await collect()
        CraneMutationBus.postImageMutated()
    }

    @discardableResult
    func collect() async throws -> Bool {
        try await collectWithChangeDetection()
    }

    private func collectWithChangeDetection() async throws -> Bool {
        let previousIDs = Set(images.map { $0.id })

        let currentImages = try await ClientImage.list()
        var currentIDs: Set<String> = []

        for clientImage in currentImages {
            currentIDs.insert(clientImage.reference)
            let target =
                images.first(where: { $0.id == clientImage.reference })
                ?? Image(image: clientImage)
            try await target.setImage(image: clientImage)
            images.insert(target)
        }

        let imagesToRemove = images.filter { !currentIDs.contains($0.id) && $0.status != .fetching }
        imagesToRemove.forEach { images.remove($0) }

        let newIDs = Set(images.map { $0.id })
        let tracker = self.tracker
        Task { @MainActor in
            tracker?.recordSuccess()
        }
        return previousIDs != newIDs
    }

    func reset() async throws {
        images.removeAll()
        try await self.collect()
    }
}
