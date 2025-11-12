//
//  ContainerLogsView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import SwiftUI

struct ContainerLogsView: View {
    let handleMetadata: ContainerLogsMetadata
    let containerMetadata: ContainerMetadata
    let handleIndex: Int
    
    var body: some View {
        VStack(spacing: 10) {
            SelectableLogText(
                logs: Binding(
                    get: { handleMetadata.logs.map { $0.message } },
                    set: { _ in /* Read-only; updates via VM */ }
                ),
                userScrolled: Binding(
                    get: { handleMetadata.userScrolled },
                    set: { containerMetadata.logHandles[handleIndex].userScrolled = $0 }
                ),
                shouldFollow: Binding(
                    get: { handleMetadata.followLogs },
                    set: { containerMetadata.logHandles[handleIndex].followLogs = $0 }
                ),
                forceScroll: Binding(
                    get: { handleMetadata.forceScroll },
                    set: { containerMetadata.logHandles[handleIndex].forceScroll = $0 }
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cornerRadius(8)
            
            Toggle("Follow logs", isOn: Binding(
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
        }
    }
}
