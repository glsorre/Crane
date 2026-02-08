//
//  PublishedPortLabel.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 22/11/25.
//

import SwiftUI

struct PublishedPortLabel: View {
    let hostPort: Int
    let containerPort: Int

    init(hostPort: Int, containerPort: Int) {
        self.hostPort = hostPort
        self.containerPort = containerPort
    }

    var body: some View {
        HStack(spacing: Spacing.xxxs) {
            PortLabel(port: hostPort, host: true)
            SwiftUI.Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            PortLabel(port: containerPort)
        }
    }
}
