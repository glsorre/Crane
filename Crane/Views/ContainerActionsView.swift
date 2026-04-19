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
        
        HStack {
            if container?.isExited != true {
                SpinnerButton(isLoading: container?.transiting ?? true) {
                    Task {
                        if clientContainer?.status == .stopped {
                            await containersStore.startContainer(id: id)
                        } else if clientContainer?.status == .running {
                            await containersStore.stopContainer(id: id)
                        }
                    }
                } label: {
                    if (clientContainer?.status == .running) {
                        SwiftUI.Image(systemName: "stop.fill")
                    } else {
                        SwiftUI.Image(systemName: "play.fill")
                    }
                }
                .buttonStyle(.glassProminent)
                .frame(width: 50)
                if clientContainer?.status == .running {
                    if container?.autoRemove == false {
                        SpinnerButton(isLoading: container?.transiting ?? true) {
                            Task {
                                await containersStore.restartContainer(id: id)
                            }
                        } label: {
                            SwiftUI.Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.glass)
                        .frame(width: 44)
                        .help(String(localized: "containerActionRestart"))
                    }
                    Button {
                        openShell(containerID: id)
                    } label: {
                        SwiftUI.Image(systemName: "terminal.fill")
                            .font(Font.system(size: 11))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 50)
                    .disabled(container?.transiting ?? true)
                    .help(String(localized: "containerActionShell"))
                    .accessibilityLabel(String(localized: "containerActionShell"))
                }
            }
            if clientContainer?.status == .stopped || container?.isExited == true {
                SpinnerButton(isLoading: container?.transiting ?? true) {
                    Task {
                        await containersStore.removeContainer(id: id)
                    }
                } label: {
                    SwiftUI.Image(systemName: "trash.fill")
                        .font(Font.system(size: 11))
                }
                .buttonStyle(.glass)
                .foregroundColor(Color(.systemRed))
                .frame(width: 50)
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
