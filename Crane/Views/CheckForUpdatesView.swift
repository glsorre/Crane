//
//  CheckForUpdatesView.swift
//  Crane
//

import SwiftUI

struct CheckForUpdatesView: View {
    @ObservedObject var updaterModel: UpdaterModel

    var body: some View {
        Button("checkForUpdates") {
            updaterModel.checkForUpdates()
        }
        .disabled(!updaterModel.canCheckForUpdates)
    }
}
