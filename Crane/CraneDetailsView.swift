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

    init(container: Container, stores: CraneStores) {
        self.container = container
        self._viewModel = State(initialValue: DetailsViewModel(container: container, stores: stores))
    }

    var body: some View {
        let clientContainer = viewModel.container.snapshot

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
                ContainerDetailsInfoView(snapshot: clientContainer, metrics: viewModel.metrics)
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
        .navigationTitle(clientContainer.id)
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
                    .buttonStyle(.glassProminent)
                }
                if clientContainer.status == .running {
                    if viewModel.container.autoRemove == false {
                        ToolbarItem {
                            SpinnerButton(isLoading: viewModel.container.transiting) {
                                Task {
                                    await viewModel.restartContainer()
                                }
                            } label: {
                                Label(String(localized: "containerActionRestart"), systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    ToolbarItem {
                        Button {
                            viewModel.openShellInTerminal()
                        } label: {
                            Label(String(localized: "containerActionShell"), systemImage: "terminal.fill")
                        }
                        .buttonStyle(.borderless)
                        .disabled(viewModel.container.transiting)
                    }
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
