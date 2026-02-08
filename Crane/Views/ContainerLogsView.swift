//
//  ContainerLogsView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import SwiftUI

struct ContainerLogsView: View {
    @Bindable var viewModel: DetailsViewModel

    var body: some View {
        let handleIndex = viewModel.currentHandle
        let handleMetadata = viewModel.logHandles[handleIndex] ?? .init()

        VStack(spacing: Spacing.xs) {
            if viewModel.logHandles.count > 1 {
                Picker("Log Handle", selection: $viewModel.currentHandle) {
                    ForEach(Array(viewModel.logHandles.keys.sorted()), id: \.self) { index in
                        Text(viewModel.getHandleName(handleIndex: index)).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 300)
            }

            SelectableLogText(
                logs: Binding(
                    get: { handleMetadata.logs.map { $0.message } },
                    set: { _ in }
                ),
                userScrolled: Binding(
                    get: { handleMetadata.userScrolled },
                    set: { handleMetadata.userScrolled = $0 }
                ),
                shouldFollow: Binding(
                    get: { handleMetadata.followLogs },
                    set: { handleMetadata.followLogs = $0 }
                ),
                forceScroll: Binding(
                    get: { handleMetadata.forceScroll },
                    set: { handleMetadata.forceScroll = $0 }
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Toggle("followLogs", isOn: Binding(
                get: { handleMetadata.followLogs },
                set: { newValue in
                    handleMetadata.followLogs = newValue
                    if newValue {
                        handleMetadata.userScrolled = false
                        handleMetadata.forceScroll = true
                    }
                }
            ))
            .controlSize(.small)
            .toggleStyle(.switch)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .onChange(of: viewModel.currentHandle) { _, newValue in
            viewModel.start(handleIndex: newValue)
        }
    }
}
