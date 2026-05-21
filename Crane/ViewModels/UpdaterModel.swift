//
//  UpdaterModel.swift
//  Crane
//

import Combine
import Sparkle
import SwiftUI

@MainActor
final class UpdaterModel: ObservableObject {
    private let updater: SPUUpdater
    private var cancellables: Set<AnyCancellable> = []

    @Published var canCheckForUpdates: Bool = false
    @Published var automaticallyChecksForUpdates: Bool {
        didSet { updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates }
    }
    @Published var automaticallyDownloadsUpdates: Bool {
        didSet { updater.automaticallyDownloadsUpdates = automaticallyDownloadsUpdates }
    }

    var lastUpdateCheckDate: Date? { updater.lastUpdateCheckDate }

    init(updater: SPUUpdater) {
        self.updater = updater
        self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        self.automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates

        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canCheckForUpdates = $0 }
            .store(in: &cancellables)
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}
