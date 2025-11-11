//
//  ContainerDetailsView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerClient
import ContainerNetworkService
import SwiftUI

struct ContainerDetailsView: View {
    @Binding var viewModel: ViewModel
    let container: ClientContainer
    
    var body: some View {
        let metadata = viewModel.containersMetadata?.fromIndex(container.id)
          

        if metadata?.loadingLogs ?? true {
                ProgressView("Loading logs...")
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .onAppear {
                        if let id = viewModel.currentContainerId {
                            Task {
                                await viewModel.initContainerLogs(for: id)
                            }
                        }
                    }
            } else if let metadata = metadata, !metadata.logHandles.isEmpty {
                TabView(selection: $viewModel.selectedLogHandleIndex) {
                    ForEach(Array(metadata.logHandles.enumerated()), id: \.offset) { index, handleMetadata in
                        HStack (spacing: 16) {
                            ContainerDetailsInfoView(viewModel: $viewModel, container: container)
                            ContainerLogsView(handleMetadata: handleMetadata, containerMetadata: metadata, handleIndex: index)
                        }
                        .tabItem {
                            Text(metadata.getHandleName(handleIndex: index))
                        }
                        .tag(index)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tabViewStyle(.automatic)
                .onChange(of: viewModel.selectedLogHandleIndex) { oldValue, newValue in
                    // Force scroll to bottom when switching tabs if follow logs is enabled and no user scroll
                    if newValue < metadata.logHandles.count,
                       metadata.logHandles[newValue].followLogs && !metadata.logHandles[newValue].userScrolled {
                        metadata.logHandles[newValue].forceScroll = true
                    }
                }
                .padding()
                .toolbar {
                    if viewModel.currentContainerId != nil,
                       let metadata = viewModel.containersMetadata?.fromIndex(viewModel.currentContainerId!) {
                        ToolbarItem {
                            SpinnerButton(isLoading: metadata.transiting) {
                                Task {
                                    if viewModel.currentContainer.status == .stopped {
                                        await viewModel.startContainer(id: viewModel.currentContainerId!)
                                    } else if viewModel.currentContainer.status == .running {
                                        await viewModel.stopContainer(id: viewModel.currentContainerId!)
                                    }
                                }
                            } label: {
                                if (viewModel.currentContainer.status == .running) {
                                    Label("", systemImage: "stop.fill")
                                } else {
                                    Label("", systemImage: "play.fill")
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        if viewModel.currentContainer.status == .stopped {
                            ToolbarItem {
                                SpinnerButton(isLoading: metadata.removing) {
                                    Task {
                                        await viewModel.removeContainer(id: viewModel.currentContainerId!)
                                    }
                                } label: {
                                    Label("", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            } else {
                Text("No logs available for this container.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
}
