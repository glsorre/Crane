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
        HStack(spacing: Spacing.xxs) {
            Text("\(port)")
                .font(.callout)
                .monospaced()
            if host {
                Link(destination: URL(string: "http://localhost:\(port)")!) {
                    SwiftUI.Image(systemName: "link")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            CopyButton(text: "\(port)")
        }
        .copyableValueStyle()
    }
}
