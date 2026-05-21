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
                GlowingStatusDot(
                    color: color,
                    isAnimated: tracker.health != .lost
                )
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, Spacing.xxs)
            .padding(.horizontal, Spacing.sm)
            .background(
                Capsule()
                    .fill(Color(.controlBackgroundColor).opacity(0.38))
            )
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showDetails, arrowEdge: .trailing) {
            ConnectionStatusDetailsView(tracker: tracker, stores: stores)
        }
    }
}
