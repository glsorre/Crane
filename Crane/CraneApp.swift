//
//  CraneApp.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 07/11/25.
//

import Sparkle
import SwiftUI

@main
struct CraneApp: App {
    @State private var stores: CraneStores = {
        let stores = CraneStores()
        stores.start()
        return stores
    }()

    private let updaterController: SPUStandardUpdaterController
    @StateObject private var updaterModel: UpdaterModel

    init() {
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updaterController = controller
        _updaterModel = StateObject(wrappedValue: UpdaterModel(updater: controller.updater))
    }

    var body: some Scene {
        WindowGroup {
            CraneView()
                .environment(\.craneStores, stores)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updaterModel: updaterModel)
            }
        }

        #if os(macOS)
            Settings {
                CraneSettingsView()
                    .environmentObject(updaterModel)
            }
        #endif
    }
}
