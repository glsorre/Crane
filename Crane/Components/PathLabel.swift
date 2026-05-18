//
//  PathLabel.swift
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
        HStack(spacing: Spacing.xxs) {
            Text(pathUrl?.lastPathComponent ?? "")
                .font(.callout)
                .monospaced()
                .help(path)
            if host, let pathUrl {
                Button(
                    action: {
                        NSWorkspace.shared.activateFileViewerSelecting([pathUrl])
                    },
                    label: {
                        SwiftUI.Image(systemName: "folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                )
                .buttonStyle(.borderless)
            }
            CopyButton(text: path)
        }
        .copyableValueStyle()
    }
}
