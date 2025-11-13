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
    @Binding var viewModel: CraneViewModel
    
    var body: some View {
        let container = viewModel.currentContainer
        let metadata = viewModel.containersMetadata?[viewModel.currentContainerId ?? ""] ?? nil
        
        if viewModel.currentContainerId != nil && metadata?.removing == false {
            TabView(selection: $viewModel.currentLogHandle) {
                ForEach(Array(metadata!.logHandles.enumerated()), id: \.offset) { index, handleMetadata in
                    HStack (spacing: 16) {
                        ContainerDetailsInfoView(viewModel: $viewModel)
                        if !metadata!.logHandles.isEmpty {
                            ContainerLogsView(handleMetadata: handleMetadata, containerMetadata: metadata!, handleIndex: index)
                        } else {
                            ProgressView("loadingLogs")
                                .progressViewStyle(CircularProgressViewStyle())
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                    }
                    .tabItem {
                        Text(metadata!.getHandleName(handleIndex: index))
                    }
                    .tag(index)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabViewStyle(.automatic)
            .onAppear {
                if let id = viewModel.currentContainerId, id == container!.id {
                    Task {
                        await viewModel.initContainerLogs(for: id)
                    }
                }
            }
            .onChange(of: viewModel.currentLogHandle) { oldValue, newValue in
                // Force scroll to bottom when switching tabs if follow logs is enabled and no user scroll
                if newValue < metadata!.logHandles.count,
                   metadata!.logHandles[newValue].followLogs && !metadata!.logHandles[newValue].userScrolled {
                    metadata!.logHandles[newValue].forceScroll = true
                }
            }
            .padding()
            .toolbar {
                if viewModel.currentContainerId != nil {
                    ToolbarItem {
                        SpinnerButton(isLoading: metadata!.transiting) {
                            Task {
                                if container!.status == .stopped {
                                    await viewModel.startContainer(id: viewModel.currentContainerId!)
                                } else if container!.status == .running {
                                    await viewModel.stopContainer(id: viewModel.currentContainerId!)
                                }
                            }
                        } label: {
                            if (container!.status == .running) {
                                Label("", systemImage: "stop.fill")
                            } else {
                                Label("", systemImage: "play.fill")
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    if container!.status == .stopped {
                        ToolbarItem {
                            SpinnerButton(isLoading: metadata!.removing) {
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
        }  else {
            EmptyView()
        }
    }
}
