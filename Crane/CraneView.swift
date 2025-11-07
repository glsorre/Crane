//
//  CraneView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 06/11/25.
//

import ContainerClient
import ContainerNetworkService
import Containerization
import ContainerizationOS
import Combine
import Observation
import SwiftUI

struct GlassProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(.thinMaterial)  // Provides a "glass-like" translucent background for prominence
            .clipShape(Capsule())       // Rounds the button for a modern, prominent look
            .opacity(configuration.isPressed ? 0.8 : 1.0)  // Subtle press effect
    }
}

struct CraneView: View {
    @State private var viewModel = ViewModel()
    
    @ViewBuilder
    private var containersSidebar: some View {
        if let containers = viewModel.containers, let networks = viewModel.networks {
            List(selection: $viewModel.currentContainerId) {
                ForEach(networks.sorted(by: { $0.network < $1.network }), id: \.network) { network in
                    Section(network.network.capitalized) {
                        let containersForNetwork = Array(containers.values).filter { $0.configuration.networks.contains { $0.network == network.network } }
                        ForEach(containersForNetwork, id: \.id) { container in
                            let iconName = container.status.getIcon()  // Fixed: Use the container's status directly (no async call needed)
                            HStack {
                                Text(container.id)
                                Spacer()
                                Image(
                                    systemName: iconName
                                )
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        } else {
            EmptyView()
        }
    }
    
    private func containerDetailView(container: ClientContainer, metadata: ContainerMetadata?) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Label("\(container.configuration.resources.cpus)", systemImage: "cpu.fill")
                Label("\(container.configuration.resources.memoryInBytes / 1024 / 1024) MB", systemImage: "memorychip.fill")
                if container.status == .running {
                    VStack {
                        ForEach(container.networks, id: \.network) { network in
                            Label("\(network.address)", systemImage: "cabinet.fill")
                            .textSelection(.enabled)
                        }
                    }
                    VStack {
                        ForEach(container.configuration.publishedPorts, id: \.containerPort) { publishedPort in
                            Label("\(publishedPort.hostPort):\(publishedPort.containerPort)", systemImage: "arrow.down.left.topright.rectangle.fill")
                            .textSelection(.enabled)
                        }
                    }
                    VStack {
                        ForEach(container.configuration.publishedSockets, id: \.containerPath) { publishedSocket in
                            Label("\(publishedSocket.hostPath):\(publishedSocket.containerPath)", systemImage: "arrow.down.left.topright.rectangle.fill")
                            .textSelection(.enabled)
                        }
                    }
                }
                Spacer()
                SpinnerButton(isLoading: metadata?.transiting ?? false) {
                    Task {
                        if container.status == .stopped {
                            await viewModel.startContainer(id: container.id)
                        } else if container.status == .running {
                            await viewModel.stopContainer(id: container.id)
                        }
                    }
                } label: {
                    if (container.status == .running) {
                        Label("Stop", systemImage: "stop.fill")
                    } else {
                        Label("Start", systemImage: "play.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                if container.status == .stopped {
                    SpinnerButton(isLoading: metadata?.removing ?? false) {
                        Task {
                            await viewModel.removeContainer(id: container.id)
                        }
                    } label: {
                        Label("Remove", systemImage: "xmark.bin.fill")
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(Color(.systemRed))
                    .frame(minWidth: 80)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            
            VStack {
                if let metadata = metadata, metadata.loadingLogs {
                    ProgressView("Loading logs...")
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if let metadata = metadata {
                    ScrollViewReader { scrollReader in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                if (metadata.logsOffsets.min() ?? 0) > 0 {
                                    SpinnerButton(isLoading: metadata.loadingMoreLogs) {
                                        metadata.followLogs = false
                                        metadata.loadingMoreLogs = true
                                        Task {
                                            await viewModel.getContainerLogs(for: metadata.id, prependMore: true)
                                            metadata.loadingMoreLogs = false
                                        }
                                    } label: {
                                        Text("Load Older Logs")
                                    }
                                    .buttonStyle(.bordered)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                                }
                                
                                Text(metadata.logs.joined(separator: "\n"))
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .lineLimit(nil)
                                    .textSelection(.enabled)
                                    .id("logs")
                            }
                        }
                        .gesture(DragGesture().onEnded { _ in
                            viewModel.userScrolled = true
                        })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                        .onAppear {
                            viewModel.reader = scrollReader
                            if metadata.followLogs {
                                scrollReader.scrollTo("logs", anchor: .bottom)
                                viewModel.userScrolled = false
                            }
                        }
                        .onChange(of: metadata.logs.count) { oldValue, newValue in
                            if metadata.followLogs && !viewModel.userScrolled {
                                scrollReader.scrollTo("logs", anchor: .bottom)
                            }
                        }
                    }
                    .background(.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    Toggle("Follow logs", isOn: Binding(get: { metadata.followLogs }, set: { newValue in
                        metadata.followLogs = newValue
                        if newValue {
                            viewModel.userScrolled = false
                            if let proxy = viewModel.reader {
                                proxy.scrollTo("logs", anchor: .bottom)
                            }
                        }
                    }))
                    .controlSize(.small)
                    .toggleStyle(.switch)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding()
    }
    
    // Extracted create sheet content into a private computed property for better organization and to avoid @ViewBuilder issues.
    private var createContainerSheet: some View {
        let cpuFormatter = NumberFormatter()
        cpuFormatter.maximumFractionDigits = 0
        cpuFormatter.numberStyle = .decimal
        return Form {
            Section {
                LabeledContent("Identifier") {
                    TextField("", text: $viewModel.containerToCreate.name)
                        .textFieldStyle(.roundedBorder)
                        .environment(\.layoutDirection, .rightToLeft)  // Right-aligns the input text and prompt
                }
                LabeledContent("Image") {
                    TextField("", text: $viewModel.containerToCreate.image)
                        .textFieldStyle(.roundedBorder)
                        .environment(\.layoutDirection, .rightToLeft)  // Right-aligns the input text and prompt
                }
                LabeledContent("CPUs") {
                    TextField("", value: $viewModel.containerToCreate.cpus, formatter: cpuFormatter)
                        .textFieldStyle(.roundedBorder)
                        .environment(\.layoutDirection, .rightToLeft)  // Right-aligns the input text and prompt
                }
                LabeledContent("Memory") {
                    TextField("", text: $viewModel.containerToCreate.memory)
                        .textFieldStyle(.roundedBorder)
                        .environment(\.layoutDirection, .rightToLeft)  // Right-aligns the input text and prompt
                }
                LabeledContent("Ports") {
                    TextField("", text: Binding<String>(
                        get: { viewModel.containerToCreate.publishPorts.joined(separator: ",") },
                        set: { newValue in
                            viewModel.containerToCreate.publishPorts = newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        },
                    ), prompt: Text("5000:5000,5001:5001"))
                    .textFieldStyle(.roundedBorder)
                    .environment(\.layoutDirection, .rightToLeft)  // Right-aligns the input text and prompt
                }
                LabeledContent("Networks") {
                    TextField("", text: Binding<String>(
                        get: { viewModel.containerToCreate.networks.joined(separator: ",") },
                        set: { newValue in
                            viewModel.containerToCreate.networks = newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        },
                    ), prompt: Text("network_id_1,network_id_2"))
                    .textFieldStyle(.roundedBorder)
                    .environment(\.layoutDirection, .rightToLeft)  // Right-aligns the input text and prompt
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
                                processFlags: nil, // Pass the populated instance
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
        .formStyle(.grouped) // Optional: constrain sheet width to prevent excessive expansion
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    var body: some View {
        NavigationSplitView {
            containersSidebar
        } detail: {
            if let currentId = viewModel.currentContainerId,
               let currentContainer = viewModel.containers?[currentId],  // Updated to use dict lookup
               let metadata = viewModel.containersMetadata?.fromIndex(currentId) {
                containerDetailView(container: currentContainer, metadata: metadata)
            } else {
                EmptyView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showCreateSheet = true  // Updated to match ViewModel property; removed duplicate
                } label: {
                    Label("Container", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(isPresented: Binding(get: { viewModel.showCreateSheet }, set: { viewModel.showCreateSheet = $0 })) {
            createContainerSheet
        }
        .task {
            await viewModel.initState()
            Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    await viewModel.listContainers()
                }
            }
        }
        .onChange(of: viewModel.currentContainerId) { oldValue, newValue in
            viewModel.logPollingTask?.cancel()
            viewModel.logPollingTask = nil
            
            if let id = newValue {
                viewModel.logPollingTask = Task.detached(priority: .background) {
                    await viewModel.hideAndGetContainerLogs(for: id)
                    if let metadata = await viewModel.containersMetadata?.fromIndex(id), await metadata.followLogs {
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .seconds(1))  // Formerly 5s; spaced to prevent overload
                            guard !Task.isCancelled else { break }
                            await viewModel.getContainerLogs(for: id)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    CraneView()
}
