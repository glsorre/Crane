// swiftlint:disable file_length
// SwiftUI form rendering: splitting subviews further hurts readability of
// the dialog layout (port/socket/env editors are tightly coupled).

import ContainerResource
import Observation
import SwiftUI

enum RunFocusField: Hashable {
    case name
    case executable
    case arguments
    case environment
    case workingDirectory
    case user
    
    case portHostPort(UUID)
    case portContainerPort(UUID)
    
    case mountSource(UUID)
    case mountDestination(UUID)
    
    case socketHost(UUID)
    case socketContainer(UUID)
    
    case labelKey(UUID)
    case labelValue(UUID)
    
    case sysctlKey(UUID)
    case sysctlValue(UUID)
}

struct ContainerRunView: View {
    @Binding var isPresented: Bool
    var initialImageID: String?

    @Environment(\.craneStores) private var stores
    @State private var viewModel: RunContainerViewModel
    private var imagesStore: ImagesStore { stores.images }
    private var networksStore: NetworksStore { stores.networks }
    private var volumesStore: VolumesStore { stores.volumes }
    @State private var advancedExpanded = false
    @State private var expertExpanded = false

    @FocusState private var focusedField: RunFocusField?

    init(isPresented: Binding<Bool>, initialImageID: String? = nil, stores: CraneStores) {
        self._isPresented = isPresented
        self.initialImageID = initialImageID
        self._viewModel = State(initialValue: RunContainerViewModel(stores: stores))
    }

    private var availableImages: [Image] {
        imagesStore.sortedFilteredImages.filter { $0.status == .available }
    }

    private var availableNetworks: [Network] {
        networksStore.sortedFilteredNetworks
    }

    private var availableVolumes: [CraneVolume] {
        volumesStore.sortedFilteredVolumes
    }

    var body: some View {
        DialogContainer(
            isPresented: $isPresented,
            title: "runContainer",
            systemImage: "shippingbox.fill",
            workingLabel: "runContainer",
            canSubmit: viewModel.canRun,
            perform: {
                try await viewModel.run()
            },
            primaryLabel: {
                Label(String(localized: "runContainerRun"), systemImage: "play.fill")
            },
            content: {
                Section("Basics") {
                    ContainerRunBasicsSection(
                        viewModel: viewModel,
                        availableImages: availableImages,
                        focusedField: $focusedField
                    )
                }

                Section("Command & Environment") {
                    ContainerRunCommandSection(
                        viewModel: viewModel,
                        focusedField: $focusedField
                    )
                }

                Section("Network") {
                    ContainerRunNetworkSection(
                        viewModel: viewModel,
                        availableNetworks: availableNetworks
                    )
                }

                Section("Ports") {
                    ContainerRunPortsSection(
                        viewModel: viewModel,
                        focusedField: $focusedField
                    )
                }

                Section("Storage") {
                    ContainerRunStorageSection(
                        viewModel: viewModel,
                        availableVolumes: availableVolumes,
                        focusedField: $focusedField
                    )
                }

                Section {
                    DisclosureGroup("Advanced", isExpanded: $advancedExpanded) {
                        ContainerRunAdvancedSection(
                            viewModel: viewModel,
                            focusedField: $focusedField
                        )
                        .padding(.top, Spacing.subsection)
                    }

                    DisclosureGroup("Expert", isExpanded: $expertExpanded) {
                        ContainerRunExpertSection(
                            viewModel: viewModel,
                            availableVolumes: availableVolumes,
                            focusedField: $focusedField
                        )
                        .padding(.top, Spacing.subsection)
                    }
                }
            }
        )
        .frame(width: 720, height: 640)
        .padding(Spacing.md)
        .onAppear {
            viewModel.bootstrapSelection(
                initialImageID: initialImageID,
                fallbackImageID: availableImages.first?.id
            )
            focusedField = .name
        }
        .onChange(of: availableImages.map(\.id)) {
            viewModel.bootstrapSelection(
                initialImageID: initialImageID,
                fallbackImageID: availableImages.first?.id
            )
        }
    }
}

private struct ContainerRunBasicsSection: View {
    @Bindable var viewModel: RunContainerViewModel
    let availableImages: [Image]
    var focusedField: FocusState<RunFocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.subsection) {
            if availableImages.isEmpty {
                Text("No images available. Pull or build an image first.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Image", selection: imageBinding) {
                    Text("Select image…").tag(String?.none)
                    ForEach(availableImages, id: \.id) { image in
                        Text(image.id).tag(Optional(image.id))
                    }
                }
            }

            TextField("Name", text: nameBinding, prompt: Text("Name"))
                .focused(focusedField, equals: .name)
                .premiumTextFieldStyle(isError: viewModel.nameValidationMessage != nil)

            Toggle("Keep container after exit", isOn: keepAfterExitBinding)

            if let message = viewModel.imageValidationMessage {
                InlineErrorText(message: message)
            } else if let message = viewModel.nameValidationMessage {
                InlineErrorText(message: message)
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private var imageBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedImageID },
            set: { viewModel.selectImage($0) }
        )
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { viewModel.name },
            set: { viewModel.updateName($0) }
        )
    }

    private var keepAfterExitBinding: Binding<Bool> {
        Binding(
            get: { !viewModel.autoRemove },
            set: { viewModel.autoRemove = !$0 }
        )
    }
}

private struct ContainerRunCommandSection: View {
    @Bindable var viewModel: RunContainerViewModel
    var focusedField: FocusState<RunFocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.subsection) {
            if viewModel.selectedImageID == nil {
                Text("Select an image to review or override its command.")
                    .foregroundStyle(.secondary)
            } else {
                Toggle("Use image default command", isOn: useImageDefaultCommandBinding)
                    .disabled(!viewModel.availableImageHasDefaultCommand)

                if viewModel.availableImageHasDefaultCommand {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Image default")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(viewModel.defaultCommandPreview)
                            .font(.callout)
                            .monospaced()
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, Spacing.sm)
                } else {
                    Text("This image doesn’t advertise a default command, so you need to enter one.")
                        .foregroundStyle(.secondary)
                }

                if !viewModel.useImageDefaultCommand || !viewModel.availableImageHasDefaultCommand {
                    TextField("Executable", text: executableBinding, prompt: Text("Executable"))
                        .focused(focusedField, equals: .executable)
                        .premiumTextFieldStyle(isError: viewModel.commandValidationMessage != nil)
                    TextField("Arguments", text: argumentsBinding, prompt: Text("Arguments"))
                        .focused(focusedField, equals: .arguments)
                        .premiumTextFieldStyle()
                }
            }

            TextField("Environment (one KEY=value per line)", text: environmentBinding, prompt: Text("Environment (one KEY=value per line)"), axis: .vertical)
                .lineLimit(4...8)
                .focused(focusedField, equals: .environment)
                .premiumTextFieldStyle(isError: viewModel.environmentValidationMessage != nil)

            if let message = viewModel.commandValidationMessage {
                InlineErrorText(message: message)
            } else if let message = viewModel.environmentValidationMessage {
                InlineErrorText(message: message)
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private var useImageDefaultCommandBinding: Binding<Bool> {
        Binding(
            get: { viewModel.useImageDefaultCommand },
            set: { viewModel.updateUseImageDefaultCommand($0) }
        )
    }

    private var executableBinding: Binding<String> {
        Binding(
            get: { viewModel.executable },
            set: { viewModel.updateExecutable($0) }
        )
    }

    private var argumentsBinding: Binding<String> {
        Binding(
            get: { viewModel.arguments },
            set: { viewModel.updateArguments($0) }
        )
    }

    private var environmentBinding: Binding<String> {
        Binding(
            get: { viewModel.environment },
            set: { viewModel.updateEnvironment($0) }
        )
    }
}

private struct ContainerRunNetworkSection: View {
    @Bindable var viewModel: RunContainerViewModel
    let availableNetworks: [Network]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.subsection) {
            if availableNetworks.isEmpty {
                Text("No networks available.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Network", selection: $viewModel.selectedNetworkID) {
                    Text("None").tag(String?.none)
                    ForEach(availableNetworks, id: \.id) { network in
                        Text(network.id).tag(Optional(network.id))
                    }
                }
            }
        }
        .padding(.vertical, Spacing.sm)
    }
}

private struct ContainerRunPortsSection: View {
    @Bindable var viewModel: RunContainerViewModel
    var focusedField: FocusState<RunFocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.subsection) {
            if viewModel.ports.isEmpty {
                Text("No published ports.")
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.ports) { port in
                PortRowEditor(
                    port: portBinding(for: port.id),
                    onRemove: {
                        viewModel.ports.removeAll { $0.id == port.id }
                    },
                    focusedField: focusedField
                )
            }

            Button {
                let id = viewModel.addPort()
                focusedField.wrappedValue = .portHostPort(id)
            } label: {
                Label("Add port", systemImage: "plus")
            }
            .buttonStyle(.borderless)

            if let message = viewModel.portValidationMessage {
                InlineErrorText(message: message)
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private func portBinding(for id: UUID) -> Binding<PortEntry> {
        Binding(
            get: { viewModel.ports.first { $0.id == id } ?? PortEntry() },
            set: { updatedPort in
                if let index = viewModel.ports.firstIndex(where: { $0.id == id }) {
                    viewModel.ports[index] = updatedPort
                }
            }
        )
    }
}

private struct ContainerRunStorageSection: View {
    @Bindable var viewModel: RunContainerViewModel
    let availableVolumes: [CraneVolume]
    var focusedField: FocusState<RunFocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.subsection) {
            if viewModel.mounts.isEmpty {
                Text("No folders or volumes mounted.")
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.mounts) { mount in
                MountRowEditor(
                    mount: mountBinding(for: mount.id),
                    availableVolumes: availableVolumes,
                    onRemove: {
                        viewModel.mounts.removeAll { $0.id == mount.id }
                    },
                    focusedField: focusedField
                )
            }

            HStack(spacing: Spacing.subsection) {
                Button {
                    let id = viewModel.addBindMount()
                    focusedField.wrappedValue = .mountSource(id)
                } label: {
                    Label("Add folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderless)

                Button {
                    let id = viewModel.addVolumeMount()
                    focusedField.wrappedValue = .mountDestination(id)
                } label: {
                    Label("Add volume", systemImage: "externaldrive.badge.plus")
                }
                .buttonStyle(.borderless)
                .disabled(availableVolumes.isEmpty)
            }

            if availableVolumes.isEmpty {
                Text("Create a volume in the Volumes tab to mount one here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message = viewModel.mountValidationMessage {
                InlineErrorText(message: message)
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private func mountBinding(for id: UUID) -> Binding<MountEntry> {
        Binding(
            get: { viewModel.mounts.first { $0.id == id } ?? MountEntry() },
            set: { updatedMount in
                if let index = viewModel.mounts.firstIndex(where: { $0.id == id }) {
                    viewModel.mounts[index] = updatedMount
                }
            }
        )
    }
}

private struct ContainerRunAdvancedSection: View {
    @Bindable var viewModel: RunContainerViewModel
    var focusedField: FocusState<RunFocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.subsection) {
            TextField("Working directory", text: workingDirectoryBinding, prompt: Text("Working directory"))
                .focused(focusedField, equals: .workingDirectory)
                .premiumTextFieldStyle()
            TextField("User", text: userBinding, prompt: Text("User"))
                .focused(focusedField, equals: .user)
                .premiumTextFieldStyle()
            Toggle("Allocate TTY", isOn: $viewModel.terminal)
            Toggle("Read-only root filesystem", isOn: $viewModel.readOnly)
            Stepper("runContainerCPUs: \(viewModel.cpus)", value: $viewModel.cpus, in: 1...32)
            Stepper("runContainerMemory: \(viewModel.memoryGiB) GiB", value: $viewModel.memoryGiB, in: 1...64)
        }
        .padding(.vertical, Spacing.sm)
    }

    private var workingDirectoryBinding: Binding<String> {
        Binding(
            get: { viewModel.workingDirectory },
            set: { viewModel.updateWorkingDirectory($0) }
        )
    }

    private var userBinding: Binding<String> {
        Binding(
            get: { viewModel.userString },
            set: { viewModel.updateUserString($0) }
        )
    }
}

private struct ContainerRunExpertSection: View {
    @Bindable var viewModel: RunContainerViewModel
    let availableVolumes: [CraneVolume]
    var focusedField: FocusState<RunFocusField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.subsection) {
                Text("Extra mounts")
                    .font(.headline)
                Button {
                    let id = viewModel.addTmpfsMount()
                    focusedField.wrappedValue = .mountDestination(id)
                } label: {
                    Label("Add tmpfs mount", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }

            Divider()
                .padding(.vertical, Spacing.sm)

            VStack(alignment: .leading, spacing: Spacing.subsection) {
                Text("Sockets")
                    .font(.headline)

                if viewModel.sockets.isEmpty {
                    Text("No socket forwards.")
                        .foregroundStyle(.secondary)
                }

                ForEach(viewModel.sockets) { socket in
                    SocketRowEditor(
                        socket: socketBinding(for: socket.id),
                        onRemove: {
                            viewModel.sockets.removeAll { $0.id == socket.id }
                        },
                        focusedField: focusedField
                    )
                }

                Button {
                    let id = viewModel.addSocket()
                    focusedField.wrappedValue = .socketHost(id)
                } label: {
                    Label("Add socket", systemImage: "plus")
                }
                .buttonStyle(.borderless)

                if let message = viewModel.socketValidationMessage {
                    InlineErrorText(message: message)
                }
            }

            Divider()
                .padding(.vertical, Spacing.sm)

            VStack(alignment: .leading, spacing: Spacing.subsection) {
                Text("Labels")
                    .font(.headline)
                KeyValueListEditor(
                    entries: $viewModel.labels,
                    addLabel: "Add label",
                    focusedField: focusedField,
                    keyFieldConstructor: { .labelKey($0) },
                    valueFieldConstructor: { .labelValue($0) }
                )
            }

            Divider()
                .padding(.vertical, Spacing.sm)

            VStack(alignment: .leading, spacing: Spacing.subsection) {
                Text("Sysctls")
                    .font(.headline)
                KeyValueListEditor(
                    entries: $viewModel.sysctls,
                    addLabel: "Add sysctl",
                    focusedField: focusedField,
                    keyFieldConstructor: { .sysctlKey($0) },
                    valueFieldConstructor: { .sysctlValue($0) }
                )
            }

            Divider()
                .padding(.vertical, Spacing.sm)

            VStack(alignment: .leading, spacing: Spacing.subsection) {
                Text("DNS")
                    .font(.headline)
                TextField("Nameservers (comma-separated)", text: $viewModel.dnsNameservers, prompt: Text("Nameservers (comma-separated)"))
                    .premiumTextFieldStyle()
                TextField("Domain", text: $viewModel.dnsDomain, prompt: Text("Domain"))
                    .premiumTextFieldStyle()
                TextField("Search domains (comma-separated)", text: $viewModel.dnsSearchDomains, prompt: Text("Search domains (comma-separated)"))
                    .premiumTextFieldStyle()
                TextField("Options (comma-separated)", text: $viewModel.dnsOptions, prompt: Text("Options (comma-separated)"))
                    .premiumTextFieldStyle()
            }

            Divider()
                .padding(.vertical, Spacing.sm)

            VStack(alignment: .leading, spacing: Spacing.subsection) {
                Text("Features")
                    .font(.headline)
                Toggle("Rosetta", isOn: $viewModel.rosetta)
                Toggle("Virtualization", isOn: $viewModel.virtualization)
                Toggle("SSH", isOn: $viewModel.ssh)
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private func socketBinding(for id: UUID) -> Binding<SocketEntry> {
        Binding(
            get: { viewModel.sockets.first { $0.id == id } ?? SocketEntry() },
            set: { updatedSocket in
                if let index = viewModel.sockets.firstIndex(where: { $0.id == id }) {
                    viewModel.sockets[index] = updatedSocket
                }
            }
        )
    }
}

private struct PortRowEditor: View {
    @Binding var port: PortEntry
    let onRemove: () -> Void
    var focusedField: FocusState<RunFocusField?>.Binding

    var body: some View {
        HStack(spacing: Spacing.subsection) {
            TextField("Host", text: $port.hostPort, prompt: Text("Host"))
                .focused(focusedField, equals: .portHostPort(port.id))
                .premiumTextFieldStyle()
                .frame(maxWidth: .infinity)
            Text(":")
            TextField("Container", text: $port.containerPort, prompt: Text("Container"))
                .focused(focusedField, equals: .portContainerPort(port.id))
                .premiumTextFieldStyle()
                .frame(maxWidth: .infinity)
            Picker("", selection: $port.proto) {
                Text("TCP").tag(PublishProtocol.tcp)
                Text("UDP").tag(PublishProtocol.udp)
            }
            .labelsHidden()
            .fixedSize()
            Button(action: onRemove) {
                SwiftUI.Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, Spacing.sm)
    }
}

private struct MountRowEditor: View {
    @Binding var mount: MountEntry
    let availableVolumes: [CraneVolume]
    let onRemove: () -> Void
    var focusedField: FocusState<RunFocusField?>.Binding

    var body: some View {
        HStack(spacing: Spacing.subsection) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            switch mount.type {
            case .bind:
                TextField("Host folder", text: $mount.source, prompt: Text("Host folder"))
                    .focused(focusedField, equals: .mountSource(mount.id))
                    .premiumTextFieldStyle()
                    .frame(maxWidth: .infinity)
            case .volume:
                Picker("Volume", selection: $mount.source) {
                    Text("Select volume…").tag("")
                    ForEach(availableVolumes, id: \.id) { volume in
                        Text(volume.id).tag(volume.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            case .tmpfs:
                EmptyView()
            }

            TextField("Destination", text: $mount.destination, prompt: Text("Destination"))
                .focused(focusedField, equals: .mountDestination(mount.id))
                .premiumTextFieldStyle()
                .frame(maxWidth: .infinity)

            if mount.type != .tmpfs {
                HStack(spacing: 6) {
                    Toggle(isOn: $mount.readOnly) { EmptyView() }
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                    Text("RO")
                }
                .fixedSize()
            }

            Button(action: onRemove) {
                SwiftUI.Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, Spacing.sm)
    }

    private var label: String {
        switch mount.type {
        case .bind:
            return "Folder"
        case .volume:
            return "Volume"
        case .tmpfs:
            return "tmpfs"
        }
    }
}

private struct SocketRowEditor: View {
    @Binding var socket: SocketEntry
    let onRemove: () -> Void
    var focusedField: FocusState<RunFocusField?>.Binding

    var body: some View {
        HStack(spacing: Spacing.subsection) {
            TextField("Host path", text: $socket.hostPath, prompt: Text("Host path"))
                .focused(focusedField, equals: .socketHost(socket.id))
                .premiumTextFieldStyle()
                .frame(maxWidth: .infinity)
            TextField("Container path", text: $socket.containerPath, prompt: Text("Container path"))
                .focused(focusedField, equals: .socketContainer(socket.id))
                .premiumTextFieldStyle()
                .frame(maxWidth: .infinity)
            Button(action: onRemove) {
                SwiftUI.Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, Spacing.sm)
    }
}
