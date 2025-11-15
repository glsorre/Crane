//
//  ContainerListActionsView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 15/11/25.
//

import ContainerClient
import SwiftUI

struct ContainerListActionsView: View {
    @Bindable var viewModel: CraneViewModel
    var id: String
    
    var body: some View {
        let container = viewModel.containers![id]!
        let metadata = viewModel.containersMetadata![container.id]
        HStack {
            SpinnerButton(isLoading: metadata!.transiting) {
                Task {
                    if container.status == .stopped {
                        await viewModel.startContainer(id: container.id)
                    } else if container.status == .running {
                        await viewModel.stopContainer(id: container.id)
                    }
                }
            } label: {
                if (container.status == .running) {
                    Image(systemName: "stop.fill")
                } else {
                    Image(systemName: "play.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: 50)
            if container.status == .stopped {
                SpinnerButton(isLoading: metadata!.removing) {
                    Task {
                        await viewModel.removeContainer(id: container.id)
                    }
                } label: {
                    Image(systemName: "trash.fill")
                        .font(Font.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .foregroundColor(Color(.systemRed))
                .frame(maxWidth: 50)
            }
        }
    }
}
