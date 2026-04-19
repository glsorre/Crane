//
//  AttachedContainerListRow.swift
//  Crane
//

import ContainerResource
import SwiftUI

/// A nested list row for a container under an image, network, or volume group.
struct AttachedContainerListRow: View {
    @State private var appViewModel = AppViewModel.shared
    var container: Container
    /// Optional secondary text (e.g. IP or mount path), shown in secondary style.
    var detail: String?

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Circle()
                .fill(container.isExited ? .secondary : container.snapshot.status.getColor())
                .frame(width: 8, height: 8)

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
