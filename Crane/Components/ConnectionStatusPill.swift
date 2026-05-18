//
//  ConnectionStatusPill.swift
//  Crane
//

import SwiftUI

struct ConnectionStatusPill: View {
    let tracker: ConnectionHealthTracker
    let stores: CraneStores
    @State private var showDetails = false

    private var color: Color {
        switch tracker.health {
        case .healthy: return .green
        case .degraded: return .yellow
        case .lost: return .red
        }
    }

    private var label: LocalizedStringKey {
        switch tracker.health {
        case .healthy: return "statusConnected"
        case .degraded: return "statusReconnecting"
        case .lost: return "statusApiDown"
        }
    }

    var body: some View {
        Button {
            showDetails.toggle()
        } label: {
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDetails, arrowEdge: .trailing) {
            ConnectionStatusDetailsView(tracker: tracker, stores: stores)
        }
    }
}
