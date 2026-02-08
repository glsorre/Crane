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

    static func == (lhs: CraneVolume, rhs: Volume) -> Bool {
        lhs.id == rhs.name
    }

    static func == (lhs: Volume, rhs: CraneVolume) -> Bool {
        lhs.name == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var id: String
    var volume: Volume
    var transiting: Bool

    init(volume: Volume) {
        self.id = volume.name
        self.volume = volume
        self.transiting = false
    }

    func update(volume: Volume) {
        self.volume = volume
    }
}

@Observable
class VolumesStore {
    static let shared = VolumesStore()

    var volumes: Set<CraneVolume> = []
    var volumesTask: Task<Void, Never>? = nil
    var resetPolling: (() -> Void)?

    var searchText: String = ""

    var sortedFilteredVolumes: [CraneVolume] {
        volumes
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
        self.volumesTask?.cancel()
    }

    func start() {
        guard AppSettings.autoRefresh else { return }
        let (task, reset) = startAdaptivePolling(
            baseInterval: { AppSettings.refreshInterval },
            maxInterval: { AppSettings.maxPollingInterval }
        ) {
            try await self.collectWithChangeDetection()
        }
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
        var currentVolumesSet: Set<CraneVolume> = Set()

        for vol in currentVolumes {
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
        return previousIDs != newIDs
    }

    func reset() async throws {
        volumes.removeAll()
        try await self.collect()
    }

    var hasUnusedVolumes: Bool {
        let containersForVolume = ContainersStore.shared.containersForVolume
        return volumes.contains { volume in
            (containersForVolume[volume.id] ?? []).isEmpty
        }
    }

    func pruneVolumes() async {
        let containersForVolume = ContainersStore.shared.containersForVolume
        let unusedVolumes = volumes.filter { volume in
            (containersForVolume[volume.id] ?? []).isEmpty
        }

        for volume in unusedVolumes {
            volume.transiting = true
            do {
                try await ClientVolume.delete(name: volume.id)
                volumes.remove(volume)
            } catch {
                volume.transiting = false
                AppViewModel.shared.showError(.volumeRemoveFailed(error.localizedDescription))
            }
        }
        RefreshCoordinator.shared.volumeMutated()
    }

    func removeVolume(name: String) async {
        guard let volume = volumes.first(where: { $0.id == name }) else { return }
        volume.transiting = true
        do {
            try await ClientVolume.delete(name: volume.id)
            volumes.remove(volume)
        } catch {
            volume.transiting = false
            AppViewModel.shared.showError(.volumeRemoveFailed(error.localizedDescription))
        }
        RefreshCoordinator.shared.volumeMutated()
    }

    func createVolume(name: String) async throws {
        let volume = try await ClientVolume.create(name: name)
        let volumeModel = CraneVolume(volume: volume)
        volumes.insert(volumeModel)
        RefreshCoordinator.shared.volumeMutated()
    }
}
