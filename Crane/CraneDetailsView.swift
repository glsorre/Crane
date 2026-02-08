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

        VStack(spacing: Spacing.md) {
            Picker("Tab", selection: $viewModel.selectedTab) {
                ForEach(DetailsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue.capitalized).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 300)

            switch viewModel.selectedTab {
            case .information:
                ContainerDetailsInfoView(container: clientContainer, metrics: viewModel.metrics)
            case .logs:
                if !viewModel.logHandles.isEmpty {
                    ContainerLogsView(viewModel: viewModel)
                } else {
                    ProgressView("loadingLogs")
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.bootstrap()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.md)
        .toolbar {
            if !container.isExited {
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
                            Label("stop", systemImage: "stop.fill")
                        } else {
                            Label("start", systemImage: "play.fill")
                        }
                    }
                    .buttonStyle(.glass)
                }
            }
            if clientContainer.status == .stopped || container.isExited {
                ToolbarItem {
                    SpinnerButton(isLoading: viewModel.container.transiting) {
                        Task {
                            await viewModel.removeContainer()
                        }
                    } label: {
                        Label("remove", systemImage: "trash")
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }
}
