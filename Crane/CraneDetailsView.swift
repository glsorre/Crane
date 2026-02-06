//
//  ContainerDetailsView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerAPIClient
import ContainerResource
import Containerization
import SwiftUI

struct CraneDetailsView: View {
    @State var viewModel: DetailsViewModel
    var container: Container
    
    init(container: Container) {
        self.container = container
        self._viewModel = State(initialValue: DetailsViewModel(container: container))
    }
    
    var body: some View {
        let clientContainer = viewModel.container.container
        
        TabView(selection: $viewModel.currentHandle) {
            ForEach(0..<viewModel.logHandles.count, id: \.self) { tabIndex in
                HStack(spacing: 16) {
                    ContainerDetailsInfoView(container: clientContainer)
                    if !viewModel.logHandles.isEmpty {
                        ContainerLogsView(viewModel: viewModel)
                    } else {
                        ProgressView("loadingLogs")
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                }
                .tabItem {
                    Text(viewModel.getHandleName(handleIndex: tabIndex))
                }
                .tag(tabIndex)
            }
        }
        .onAppear {
            Task {
                if !viewModel.logHandles.isEmpty {
                    await viewModel.bootstrap()
                }
            }
        }
        .onChange(of: viewModel.currentHandle) { _, newValue in
            viewModel.start(handleIndex: newValue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tabViewStyle(.automatic)
        .padding()
        .toolbar {
            ToolbarItem {
                SpinnerButton(isLoading: viewModel.container.transiting) {
                    Task {
                        if clientContainer.status == .stopped {
                            await viewModel.startContainer()
                        } else if clientContainer.status == .running {
                            await viewModel.stopContainer()
                        }
                    }
                } label: {
                    if clientContainer.status == .running {
                        Label("", systemImage: "stop.fill")
                    } else {
                        Label("", systemImage: "play.fill")
                    }
                }
                
                .buttonStyle(.bordered)
            }
            if clientContainer.status == .stopped {
                ToolbarItem {
                    SpinnerButton(isLoading: viewModel.container.transiting) {
                        Task {
                            await viewModel.removeContainer()
                        }
                    } label: {
                        Label("", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
