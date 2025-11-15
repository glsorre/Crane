//
//  ContainerLogsView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import SwiftUI

struct ContainerLogsView: View {
    @Bindable var viewModel: CraneViewModel
    let id: String
    
    var body: some View {
        let handleIndex = viewModel.currentHandle
        let metadata = viewModel.containersMetadata![id]!
        let handleMetadata = metadata.logHandles[handleIndex]!
        VStack(spacing: 10) {
            SelectableLogText(
                logs: Binding(
                    get: { handleMetadata.logs.map { $0.message } },
                    set: { _ in /* Read-only; updates via VM */ }
                ),
                userScrolled: Binding(
                    get: { handleMetadata.userScrolled },
                    set: { metadata.logHandles[handleIndex]!.userScrolled = $0 }
                ),
                shouldFollow: Binding(
                    get: { handleMetadata.followLogs },
                    set: { metadata.logHandles[handleIndex]!.followLogs = $0 }
                ),
                forceScroll: Binding(
                    get: { handleMetadata.forceScroll },
                    set: { metadata.logHandles[handleIndex]!.forceScroll = $0 }
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cornerRadius(8)
            
            Toggle("followLogs", isOn: Binding(
                get: { handleMetadata.followLogs },
                set: { newValue in
                    handleMetadata.followLogs = newValue
                    if newValue {
                        handleMetadata.userScrolled = false
                        handleMetadata.forceScroll = true  // Force immediate scroll
                    }
                }
            ))
            .controlSize(.small)
            .toggleStyle(.switch)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .onAppear {
                Task {
                    if !handleMetadata.followLogs {
                        handleMetadata.userScrolled = false
                        handleMetadata.forceScroll = true
                    }
                    
                    handleMetadata.logPollingTask?.cancel()
                    
                    handleMetadata.logPollingTask = Task {
                        try? await Task.sleep(for: .seconds(Int(UserDefaults().integer(forKey: "logsInterval"))))
                        await viewModel.watchContainerLogs(for: id, handle: handleIndex)
                    }
                }
            }
        }
    }
}
