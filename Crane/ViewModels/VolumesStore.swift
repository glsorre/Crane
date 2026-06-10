//
//  VolumesStore.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 08/02/26.
//

import ContainerAPIClient
import ContainerResource
import ContainerizationOCI
import Foundation
import Observation
import SwiftUI
import os.log

@Observable
class CraneVolume: Identifiable, Hashable {
    static func == (lhs: CraneVolume, rhs: CraneVolume) -> Bool {
        lhs.id == rhs.id
    }

    static func == (lhs: CraneVolume, rhs: VolumeConfiguration) -> Bool {
        lhs.id == rhs.name
    }

    static func == (lhs: VolumeConfiguration, rhs: CraneVolume) -> Bool {
        lhs.name == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var id: String
    var volume: VolumeConfiguration
    var transiting: Bool

    init(volume: VolumeConfiguration) {
        self.id = volume.name
        self.volume = volume
        self.transiting = false
    }

    func update(volume: VolumeConfiguration) {
        self.volume = volume
    }
}

@Observable
class VolumesStore {
    private let onError: @MainActor (CraneError) -> Void
    private let containersForVolumeProvider: () -> [String: [Container]]
    private let tracker: ConnectionHealthTracker?

    var volumes: Set<CraneVolume> = []
    var volumesTask: Task<Void, Never>?
    var resetPolling: (() -> Void)?

    private var pendingDeletionIDs: Set<String> = []

    var searchText: String = ""

    var sortedFilteredVolumes: [CraneVolume] {
        volumes
            .sorted { $0.id < $1.id }
            .filter { self.searchText.isEmpty || ($0.id.contains(self.searchText)) }
    }

    init(
        onError: @escaping @MainActor (CraneError) -> Void = { _ in },
        containersForVolume: @escaping () -> [String: [Container]] = { [:] },
        tracker: ConnectionHealthTracker? = nil
    ) {
        self.onError = onError
        self.containersForVolumeProvider = containersForVolume
        self.tracker = tracker
    }

    deinit {
        self.stop()
    }

    func stop() {
        self.volumesTask?.cancel()
    }

    func start() {
        guard AppSettings.autoRefresh else { return }
        let tracker = self.tracker
        let (task, reset) = startAdaptivePolling(
            baseInterval: { AppSettings.refreshInterval },
            maxInterval: { AppSettings.maxPollingInterval },
            isVisible: { PollingVisibility.isVisible(for: .volumes) },
            onError: { error in
                Task { @MainActor in
                    tracker?.recordFailure(resource: .volumes, error: error)
                }
            },
            work: {
                try await self.collectWithChangeDetection()
            }
        )
        self.volumesTask = task
        self.resetPolling = reset
    }

    @discardableResult
    func collect() async throws -> Bool {
        try await collectWithChangeDetection()
    }

    private func collectWithChangeDetection() async throws -> Bool {
        let previousIDs = Set(volumes.map { $0.id })

        let currentVolumes = try await ClientVolume.list()
        let currentIDs = Set(currentVolumes.map(\.name))
        pendingDeletionIDs.formIntersection(currentIDs)

        var currentVolumesSet: Set<CraneVolume> = Set()

        for vol in currentVolumes where !pendingDeletionIDs.contains(vol.name) {
            let newVolume = CraneVolume(volume: vol)
            currentVolumesSet.insert(newVolume)
            if let volume = volumes.first(where: { $0.id == newVolume.id }) {
                volume.update(volume: vol)
            }
            volumes.insert(newVolume)
        }

        let volumesToRemove = volumes.subtracting(currentVolumesSet)
        volumesToRemove.forEach { volumeToRemove in
            volumes.remove(volumeToRemove)
        }

        let newIDs = Set(volumes.map { $0.id })
        let tracker = self.tracker
        Task { @MainActor in
            tracker?.recordSuccess()
        }
        return previousIDs != newIDs
    }

    func reset() async throws {
        volumes.removeAll()
        pendingDeletionIDs.removeAll()
        try await self.collect()
    }

    func beginPendingDeletion(_ id: String) {
        pendingDeletionIDs.insert(id)
    }

    func endPendingDeletion(_ id: String) {
        pendingDeletionIDs.remove(id)
    }

    var hasUnusedVolumes: Bool {
        let containersForVolume = containersForVolumeProvider()
        return volumes.contains { volume in
            (containersForVolume[volume.id] ?? []).isEmpty
        }
    }

    func pruneVolumes() async {
        let containersForVolume = containersForVolumeProvider()
        let unusedVolumes = volumes.filter { volume in
            (containersForVolume[volume.id] ?? []).isEmpty
        }

        for volume in unusedVolumes {
            volume.transiting = true
            beginPendingDeletion(volume.id)
            do {
                try await ClientVolume.delete(name: volume.id)
                volumes.remove(volume)
            } catch {
                endPendingDeletion(volume.id)
                volume.transiting = false
                Log.volumes.error("prune delete failed for \(volume.id): \(error.localizedDescription, privacy: .public)")
                onError(.volumeRemoveFailed(underlying: error))
            }
        }
        CraneMutationBus.postVolumeMutated()
    }

    func removeVolume(name: String) async {
        guard let volume = volumes.first(where: { $0.id == name }) else { return }
        volume.transiting = true
        beginPendingDeletion(volume.id)
        do {
            try await ClientVolume.delete(name: volume.id)
            volumes.remove(volume)
        } catch {
            endPendingDeletion(volume.id)
            volume.transiting = false
            Log.volumes.error("removeVolume(\(name)) failed: \(error.localizedDescription, privacy: .public)")
            onError(.volumeRemoveFailed(underlying: error))
        }
        CraneMutationBus.postVolumeMutated()
    }

    func createVolume(name: String) async throws {
        endPendingDeletion(name)
        let volume = try await ClientVolume.create(name: name)
        let volumeModel = CraneVolume(volume: volume)
        volumes.insert(volumeModel)
        CraneMutationBus.postVolumeMutated()
    }
}
