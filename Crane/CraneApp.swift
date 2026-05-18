//
//  CraneApp.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 07/11/25.
//

import SwiftUI

@main
struct CraneApp: App {
    @State private var stores: CraneStores = {
        let stores = CraneStores()
        stores.start()
        return stores
    }()

    var body: some Scene {
        WindowGroup {
            CraneView()
                .environment(\.craneStores, stores)
        }

        #if os(macOS)
        Settings {
            CraneSettingsView()
        }
        #endif
    }
}
