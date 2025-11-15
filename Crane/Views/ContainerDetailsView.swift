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
    @Bindable var viewModel: CraneViewModel
    var id: String
    
    var body: some View {
        let container = viewModel.containers![id]
        let metadata = viewModel.containersMetadata![id]
        
        if metadata?.removing == false {
            let sortedKeys = metadata!.logHandles.keys.sorted()
            TabView(selection: $viewModel.currentHandle) {
                ForEach(0..<sortedKeys.count, id: \.self) { tabIndex in
                    let handleIndex = sortedKeys[tabIndex]
                    HStack(spacing: 16) {
                        ContainerDetailsInfoView(viewModel: viewModel, id: id)
                        if !metadata!.logHandles.isEmpty {
                            ContainerLogsView(viewModel: viewModel, id: id)
                        } else {
                            ProgressView("loadingLogs")
                                .progressViewStyle(CircularProgressViewStyle())
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                    }
                    .tabItem {
                        Text(metadata!.getHandleName(handleIndex: handleIndex))
                    }
                    .tag(tabIndex)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .tabViewStyle(.automatic)
            .onAppear {
                Task {
                    await viewModel.initContainerLogs(for: id)
                }
            }
            .onChange(of: viewModel.currentHandle) { oldValue, newValue in
                // Force scroll to bottom when switching tabs if follow logs is enabled and no user scroll
                if newValue < sortedKeys.count {
                    let handleIndex = sortedKeys[newValue]
                    if let handleMetadata = metadata!.logHandles[handleIndex],
                       handleMetadata.followLogs && !handleMetadata.userScrolled {
                        metadata!.logHandles[handleIndex]!.forceScroll = true
                    }
                }
            }
            .padding()
            .toolbar {
                ToolbarItem {
                    SpinnerButton(isLoading: metadata!.transiting) {
                        Task {
                            if container!.status == .stopped {
                                await viewModel.startContainer(id: id)
                            } else if container!.status == .running {
                                await viewModel.stopContainer(id: id)
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
                                await viewModel.removeContainer(id: id)
                            }
                        } label: {
                            Label("", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        } else {
            EmptyView()
        }
    }
}

