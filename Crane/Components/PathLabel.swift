//
//  PortLabel.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 10/11/25.
//

import SwiftUI

struct PathLabel: View {
    let path: String
    let pathUrl: URL?
    let host: Bool
    
    init(path: String, host: Bool = false) {
        self.path = path
        self.pathUrl = URL(fileURLWithPath: path)
        self.host = host
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Text(pathUrl?.lastPathComponent ?? "")
                .monospaced()
                .help(path)
                .padding(4)
            if host {
                Button (action: {
                    NSWorkspace.shared.activateFileViewerSelecting([pathUrl!])
                }){
                    SwiftUI.Image(systemName: "folder")
                        .renderingMode(.template)
                        .foregroundColor(Color.accentColor)
                }
            }
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
            }) {
                SwiftUI.Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .padding(4)
        }
    }
}
