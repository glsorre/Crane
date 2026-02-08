//
//  PublishedPathLabel.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 22/11/25.
//

import SwiftUI

struct PublishedPathLabel: View {
    let hostPath: String
    let containerPath: String

    init(hostPath: String, containerPath: String) {
        self.hostPath = hostPath
        self.containerPath = containerPath
    }

    var body: some View {
        HStack(spacing: Spacing.xxxs) {
            PathLabel(path: hostPath, host: true)
            SwiftUI.Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            PathLabel(path: containerPath)
        }
    }
}
