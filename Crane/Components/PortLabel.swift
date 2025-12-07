//
//  PortLabel.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 10/11/25.
//

import SwiftUI

struct PortLabel: View {
    let port: Int
    let host: Bool
    
    init(port: Int, host: Bool = false) {
        self.port = port
        self.host = host
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Text("\(String(Int(port)))")
                .monospaced()
                .padding(4)
            if (host) {
                Link(destination: URL(string: "http://localhost:\(port)")!) {
                    SwiftUI.Image(systemName: "link")
                }
            }
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(port)", forType: .string)
            }) {
                SwiftUI.Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .padding(4)
        }
    }
}
