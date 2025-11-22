//
//  PublishedPathLabel.swift
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
        HStack(spacing: 0) {
            PortLabel(port: hostPort, host: true)
                .background(Color(.tertiaryLabelColor))
                .cornerRadius(4)
            Text(":")
                .monospaced()
            PortLabel(port: containerPort)
                .background(Color(.tertiaryLabelColor))
                .cornerRadius(4)
        }
    }
}
