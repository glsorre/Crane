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
        HStack (spacing: 0) {
            PathLabel(path: hostPath, host: true)
                .background(Color(.tertiaryLabelColor))
                .cornerRadius(4)
            Text(":")
                .monospaced()
            PathLabel(path: containerPath)
                .background(Color(.tertiaryLabelColor))
                .cornerRadius(4)
        }
    }
}
