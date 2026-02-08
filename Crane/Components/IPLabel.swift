//
//  IPLabel.swift
//  Crane
//

import SwiftUI

struct IPLabel: View {
    let ip: String
    var networkName: String?

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            if let networkName {
                Text(networkName)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text(ip)
                .font(.callout)
                .monospaced()
            CopyButton(text: ip)
        }
        .copyableValueStyle()
    }
}
