//
//  AttachedContainerListRow.swift
//  Crane
//

import ContainerResource
import SwiftUI

/// A nested list row for a container under an image, network, or volume group.
struct AttachedContainerListRow: View {
    @Environment(\.craneStores) private var stores
    private var appViewModel: AppViewModel { stores.app }
    var container: Container
    /// Optional secondary text (e.g. IP or mount path), shown in secondary style.
    var detail: String?

    var body: some View {
        HStack(spacing: Spacing.xs) {
            GlowingStatusDot(
                color: container.isExited ? .secondary : container.snapshot.status.getColor(),
                isAnimated: !container.isExited && container.snapshot.status == .running
            )

            Text(container.id)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }

            Spacer()

            ContainerActionsView(id: container.id)
        }
        .padding(.leading, Spacing.sm)
        .contentShape(Rectangle())
        .onTapGesture {
            appViewModel.openContainerDetail(container)
        }
    }
}
