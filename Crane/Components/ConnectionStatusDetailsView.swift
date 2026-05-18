//
//  ConnectionStatusDetailsView.swift
//  Crane
//

import SwiftUI

struct ConnectionStatusDetailsView: View {
    let tracker: ConnectionHealthTracker
    let stores: CraneStores

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("statusDetailsTitle")
                .font(.headline)

            HStack {
                Text("statusDetailsFailures")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(tracker.consecutiveFailures)")
                    .font(.system(.body, design: .monospaced))
            }

            if let last = tracker.lastError {
                Divider()
                Text("statusDetailsLastError")
                    .foregroundStyle(.secondary)
                Text(last.errorDescription ?? "")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                if let detail = last.debugDetail {
                    Text(detail)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
            }

            Divider()

            Button {
                stores.containers.resetPolling?()
                stores.images.resetPolling?()
                stores.networks.resetPolling?()
                stores.volumes.resetPolling?()
            } label: {
                Label("statusRetry", systemImage: "arrow.clockwise")
            }
        }
        .padding(Spacing.md)
        .frame(width: 320)
    }
}
