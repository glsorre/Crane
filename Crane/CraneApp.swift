//
//  CraneApp.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 07/11/25.
//

import SwiftUI

@main
struct CraneApp: App {
    var body: some Scene {
        WindowGroup {
            CraneView()
        }
        
        #if os(macOS)
        Settings {
            CraneSettingsView()
        }
        #endif
    }
}

