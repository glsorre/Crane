import ContainerResource
import SwiftUI

struct ContainerRunView: View {
    @Binding var isPresented: Bool
    var initialImageID: String? = nil
    @State private var viewModel = RunContainerViewModel()
    @State private var imagesStore = ImagesStore.shared
    @State private var networksStore = NetworksStore.shared
    @State private var volumesStore = VolumesStore.shared

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack {
                Label("runContainer", systemImage: "shippingbox.fill")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Picker(String(localized: "runContainerImage"), selection: $viewModel.selectedImageID) {
                    Text(String(localized: "selectImage")).tag(String?.none)
                    ForEach(imagesStore.sortedFilteredImages.filter { $0.status == .available }, id: \.id) { image in
                        Text(image.id).tag(Optional(image.id))
                    }
                }
                .frame(maxWidth: 300)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            // MARK: Form
            Form {
                // Basic
                Section("runContainerName") {
                    TextField("runContainerName", text: $viewModel.name)
                    Toggle("runContainerAutoRemove", isOn: $viewModel.autoRemove)
                }

                // Process
                Section("runContainerProcess") {
                    TextField("runContainerCommand", text: $viewModel.command)
                    TextField("runContainerEnvironment", text: $viewModel.environment, axis: .vertical)
                        .lineLimit(3...8)
                    TextField("runContainerWorkingDirectory", text: $viewModel.workingDirectory)
                    TextField("runContainerUser", text: $viewModel.userString)
                    Toggle("runContainerTerminal", isOn: $viewModel.terminal)
                }

                // Networks
                Section("runContainerNetworks") {
                    ForEach(Array(networksStore.networks), id: \.id) { network in
                        Toggle(isOn: Binding(
                            get: { viewModel.selectedNetworks.contains(network.id) },
                            set: { isOn in
                                if isOn { viewModel.selectedNetworks.insert(network.id) }
                                else { viewModel.selectedNetworks.remove(network.id) }
                            }
                        )) {
                            Text(network.id)
                        }
                    }
                }

                // Ports
                Section("runContainerPorts") {
                    ForEach(viewModel.ports) { port in
                        let pb = portBinding(for: port.id)
                        HStack {
                            TextField("Host", text: pb.hostPort)
                                .textFieldStyle(.plain)
                                .frame(maxWidth: .infinity)
                            Text(":")
                            TextField("Container", text: pb.containerPort)
                                .textFieldStyle(.plain)
                                .frame(maxWidth: .infinity)
                            Picker("", selection: pb.proto) {
                                Text("TCP").tag(PublishProtocol.tcp)
                                Text("UDP").tag(PublishProtocol.udp)
                            }
                            .fixedSize()
                            .labelsHidden()
                            Button {
                                viewModel.ports.removeAll { $0.id == port.id }
                            } label: {
                                SwiftUI.Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    Button {
                        viewModel.ports.append(PortEntry())
                    } label: {
                        Label("runContainerAddPort", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }

                // Mounts
                Section("runContainerMounts") {
                    ForEach(viewModel.mounts) { mount in
                        let mb = mountBinding(for: mount.id)
                        HStack {
                            Picker("", selection: mb.type) {
                                ForEach(MountType.allCases, id: \.self) { t in
                                    Text(t.rawValue).tag(t)
                                }
                            }
                            .fixedSize()
                            .labelsHidden()
                            if mount.type == .volume {
                                Picker("Source", selection: mb.source) {
                                    Text("Select...").tag("")
                                    ForEach(volumesStore.sortedFilteredVolumes, id: \.id) { vol in
                                        Text(vol.id).tag(vol.id)
                                    }
                                }
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                            } else if mount.type == .bind {
                                TextField("Source", text: mb.source)
                                    .textFieldStyle(.plain)
                                    .frame(maxWidth: .infinity)
                            }
                            TextField("Destination", text: mb.destination)
                                .textFieldStyle(.plain)
                                .frame(maxWidth: .infinity)
                            HStack(spacing: 4) {
                                Toggle(isOn: mb.readOnly) { }
                                    .toggleStyle(.checkbox)
                                    .labelsHidden()
                                Text("RO")
                            }
                            .fixedSize()
                            Button {
                                viewModel.mounts.removeAll { $0.id == mount.id }
                            } label: {
                                SwiftUI.Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    Button {
                        viewModel.mounts.append(MountEntry())
                    } label: {
                        Label("runContainerAddMount", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }

                // Sockets
                Section("runContainerSockets") {
                    ForEach(viewModel.sockets) { socket in
                        let sb = socketBinding(for: socket.id)
                        HStack {
                            TextField("Host path", text: sb.hostPath)
                                .textFieldStyle(.plain)
                                .frame(maxWidth: .infinity)
                            TextField("Container path", text: sb.containerPath)
                                .textFieldStyle(.plain)
                                .frame(maxWidth: .infinity)
                            Button {
                                viewModel.sockets.removeAll { $0.id == socket.id }
                            } label: {
                                SwiftUI.Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    Button {
                        viewModel.sockets.append(SocketEntry())
                    } label: {
                        Label("runContainerAddSocket", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }

                // Resources
                Section("runContainerResources") {
                    Stepper("runContainerCPUs: \(viewModel.cpus)", value: $viewModel.cpus, in: 1...32)
                    Stepper("runContainerMemory: \(viewModel.memoryGiB) GiB", value: $viewModel.memoryGiB, in: 1...64)
                }

                // Labels
                Section("runContainerLabels") {
                    KeyValueListEditor(entries: $viewModel.labels, addLabel: "runContainerAddLabel")
                }

                // Sysctls
                Section("runContainerSysctls") {
                    KeyValueListEditor(entries: $viewModel.sysctls, addLabel: "runContainerAddSysctl")
                }

                // DNS
                Section("runContainerDNS") {
                    TextField("runContainerDNSNameservers", text: $viewModel.dnsNameservers)
                    TextField("runContainerDNSDomain", text: $viewModel.dnsDomain)
                    TextField("runContainerDNSSearchDomains", text: $viewModel.dnsSearchDomains)
                    TextField("runContainerDNSOptions", text: $viewModel.dnsOptions)
                }

                // Advanced
                Section("runContainerAdvanced") {
                    Toggle("runContainerRosetta", isOn: $viewModel.rosetta)
                    Toggle("runContainerReadOnly", isOn: $viewModel.readOnly)
                    Toggle("runContainerVirtualization", isOn: $viewModel.virtualization)
                    Toggle("runContainerSSH", isOn: $viewModel.ssh)
                }
            }
            .formStyle(.grouped)

            // MARK: Status
            if let errorMsg = viewModel.error {
                HStack(alignment: .top, spacing: Spacing.xs) {
                    SwiftUI.Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(errorMsg)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xxs)
            } else if viewModel.success {
                HStack(spacing: Spacing.xs) {
                    SwiftUI.Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(String(localized: "runContainerSuccess"))
                        .font(.callout)
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xxs)
            }

            // MARK: Footer
            HStack {
                Button(String(localized: "cancel")) {
                    isPresented = false
                }
                .buttonStyle(.glass)
                Spacer()
                SpinnerButton(isLoading: viewModel.isCreating) {
                    Task {
                        await viewModel.run()
                        if viewModel.success {
                            isPresented = false
                        }
                    }
                } label: {
                    Label(String(localized: "runContainerRun"), systemImage: "play.fill")
                }
                .buttonStyle(.glassProminent)
                .disabled(viewModel.name.isEmpty || viewModel.selectedImageID == nil || viewModel.isCreating)
            }
            .padding(Spacing.sm)
        }
        .frame(width: 640, height: 580)
        .onChange(of: viewModel.selectedImageID) {
            viewModel.prefillFromImage()
        }
        .onAppear {
            if let initialImageID {
                viewModel.selectedImageID = initialImageID
            }
        }
    }

    private func portBinding(for id: UUID) -> Binding<PortEntry> {
        Binding(
            get: { viewModel.ports.first { $0.id == id } ?? PortEntry() },
            set: { val in
                if let i = viewModel.ports.firstIndex(where: { $0.id == id }) {
                    viewModel.ports[i] = val
                }
            }
        )
    }

    private func mountBinding(for id: UUID) -> Binding<MountEntry> {
        Binding(
            get: { viewModel.mounts.first { $0.id == id } ?? MountEntry() },
            set: { val in
                if let i = viewModel.mounts.firstIndex(where: { $0.id == id }) {
                    viewModel.mounts[i] = val
                }
            }
        )
    }

    private func socketBinding(for id: UUID) -> Binding<SocketEntry> {
        Binding(
            get: { viewModel.sockets.first { $0.id == id } ?? SocketEntry() },
            set: { val in
                if let i = viewModel.sockets.firstIndex(where: { $0.id == id }) {
                    viewModel.sockets[i] = val
                }
            }
        )
    }
}
