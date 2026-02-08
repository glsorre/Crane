//
//  ContainerActionsView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 15/11/25.
//

import ContainerAPIClient
import SwiftUI
import ContainerResource

struct ContainerActionsView: View {
    @State private var appViewModel = AppViewModel.shared
    @State private var containersStore = ContainersStore.shared
    var id: String
    
    var body: some View {
        let container = containersStore.containers.first(where: { $0.id == id })
        let clientContainer = container?.container
        
        HStack {
            if container?.isExited != true {
                SpinnerButton(isLoading: container?.transiting ?? true) {
                    Task {
                        if clientContainer?.status == .stopped {
                            await containersStore.startContainer(id: id)
                        } else if clientContainer?.status == .running {
                            await containersStore.stopContainer(id: id)
                        }
                    }
                } label: {
                    if (clientContainer?.status == .running) {
                        SwiftUI.Image(systemName: "stop.fill")
                    } else {
                        SwiftUI.Image(systemName: "play.fill")
                    }
                }
                .buttonStyle(.glassProminent)
                .frame(width: 50)
            }
            if clientContainer?.status == .stopped || container?.isExited == true {
                SpinnerButton(isLoading: container?.transiting ?? true) {
                    Task {
                        await containersStore.removeContainer(id: id)
                    }
                } label: {
                    SwiftUI.Image(systemName: "trash.fill")
                        .font(Font.system(size: 11))
                }
                .buttonStyle(.glass)
                .foregroundColor(Color(.systemRed))
                .frame(width: 50)
            }
        }
    }
}
