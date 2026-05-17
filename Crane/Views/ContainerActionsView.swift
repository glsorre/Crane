//
//  ContainerActionsView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 15/11/25.
//

import ContainerAPIClient
import SwiftUI
import ContainerResource

struct ContainerActionsView: View {
    @State private var containersStore = ContainersStore.shared
    var id: String

    var body: some View {
        let container = containersStore.containers.first(where: { $0.id == id })
        let clientContainer = container?.snapshot

        HStack(spacing: 4) {
            if container?.isExited != true {
                RowActionButton(
                    .primary,
                    isLoading: container?.transiting ?? true,
                    action: {
                        Task {
                            if clientContainer?.status == .stopped {
                                await containersStore.startContainer(id: id)
                            } else if clientContainer?.status == .running {
                                await containersStore.stopContainer(id: id)
                            }
                        }
                    },
                    label: {
                        if clientContainer?.status == .running {
                            SwiftUI.Image(systemName: "stop.fill")
                        } else {
                            SwiftUI.Image(systemName: "play.fill")
                        }
                    }
                )

                if clientContainer?.status == .running {
                    if container?.autoRemove == false {
                        RowActionButton(
                            .secondary,
                            isLoading: container?.transiting ?? true,
                            help: String(localized: "containerActionRestart"),
                            action: {
                                Task { await containersStore.restartContainer(id: id) }
                            },
                            label: {
                                SwiftUI.Image(systemName: "arrow.clockwise")
                            }
                        )
                    }

                    RowActionButton(
                        .tertiary,
                        isEnabled: !(container?.transiting ?? true),
                        help: String(localized: "containerActionShell"),
                        action: {
                            openShell(containerID: id)
                        },
                        label: {
                            SwiftUI.Image(systemName: "terminal.fill")
                        }
                    )
                }
            }

            if clientContainer?.status == .stopped || container?.isExited == true {
                RowActionButton(
                    .destructive,
                    isLoading: container?.transiting ?? true,
                    action: {
                        Task { await containersStore.removeContainer(id: id) }
                    },
                    label: {
                        SwiftUI.Image(systemName: "trash.fill")
                    }
                )
            }
        }
    }

    private func openShell(containerID: String) {
        do {
            try ContainerShellLauncher.openInteractiveShell(containerID: containerID)
        } catch {
            AppViewModel.shared.showError(.containerShellFailed(error.localizedDescription))
        }
    }
}
