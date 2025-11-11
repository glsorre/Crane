//
//  ContainerCreationView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import ContainerClient
import SwiftUI

struct ContainerCreationView: View {
    @Binding var viewModel: CraneViewModel
    
    private let cpuFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        formatter.numberStyle = .none
        return formatter
    }()
    
    var body: some View {
        Form {
            Section {
                LabeledContent("Identifier") {
                    TextField("", text: $viewModel.containerToCreate.name)
                        .textFieldStyle(.roundedBorder)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                LabeledContent("Image") {
                    TextField("", text: $viewModel.containerToCreate.image)
                        .textFieldStyle(.roundedBorder)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                LabeledContent("CPUs") {
                    TextField("", value: $viewModel.containerToCreate.cpus, formatter: cpuFormatter)
                        .textFieldStyle(.roundedBorder)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                LabeledContent("Memory") {
                    TextField("", text: $viewModel.containerToCreate.memory)
                        .textFieldStyle(.roundedBorder)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                LabeledContent("Ports") {
                    TextField("", text: Binding<String>(
                        get: { viewModel.containerToCreate.publishPorts.joined(separator: ",") },
                        set: { newValue in
                            viewModel.containerToCreate.publishPorts = newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        },
                    ), prompt: Text("5000:5000,5001:5001"))
                    .textFieldStyle(.roundedBorder)
                    .environment(\.layoutDirection, .rightToLeft)
                }
                LabeledContent("Networks") {
                    TextField("", text: Binding<String>(
                        get: { viewModel.containerToCreate.networks.joined(separator: ",") },
                        set: { newValue in
                            viewModel.containerToCreate.networks = newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        },
                    ), prompt: Text("network_id_1,network_id_2"))
                    .textFieldStyle(.roundedBorder)
                    .environment(\.layoutDirection, .rightToLeft)
                }
                Toggle("Autoremove", isOn: $viewModel.containerToCreate.remove)
            }
            Section {
                HStack {
                    Spacer()
                    Button("Cancel") {
                        viewModel.showCreateSheet = false
                    }
                    Spacer()
                    SpinnerButton(isLoading: viewModel.containerToCreate.creating) {
                        var resourceFlags = Flags.Resource()
                        resourceFlags.cpus = viewModel.containerToCreate.cpus
                        resourceFlags.memory = viewModel.containerToCreate.memory
                        
                        var managementFlags = Flags.Management()
                        managementFlags.publishPorts = viewModel.containerToCreate.publishPorts
                        managementFlags.networks = viewModel.containerToCreate.networks
                        
                        Task {
                            await viewModel.createContainer(
                                name: viewModel.containerToCreate.name,
                                image: viewModel.containerToCreate.image,
                                processFlags: nil,
                                managementFlags: managementFlags,
                                resourceFlags: resourceFlags,
                                registryFlags: nil,
                                remove: viewModel.containerToCreate.remove
                            )
                            viewModel.showCreateSheet = false
                        }
                    } label: {
                        Text("Create")
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
