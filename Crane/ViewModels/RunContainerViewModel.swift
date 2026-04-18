import ContainerAPIClient
import ContainerResource
import ContainerizationExtras
import ContainerizationOCI
import ContainerizationOS
import Foundation
import Observation

struct PortEntry: Identifiable {
    let id = UUID()
    var hostPort: String = ""
    var containerPort: String = ""
    var proto: PublishProtocol = .tcp
}

struct SocketEntry: Identifiable {
    let id = UUID()
    var hostPath: String = ""
    var containerPath: String = ""
}

enum MountType: String, CaseIterable {
    case bind = "Bind"
    case volume = "Volume"
    case tmpfs = "tmpfs"
}

struct MountEntry: Identifiable {
    let id = UUID()
    var type: MountType = .bind
    var source: String = ""
    var destination: String = ""
    var readOnly: Bool = false
}

struct KeyValueEntry: Identifiable {
    let id = UUID()
    var key: String = ""
    var value: String = ""

    init(key: String = "", value: String = "") {
        self.key = key
        self.value = value
    }
}

@Observable
class RunContainerViewModel {
    // Identity
    var name: String = ""
    var selectedImageID: String?
    var selectedNetworkID: String?

    // Process
    var useImageDefaultCommand: Bool = true
    var executable: String = ""
    var arguments: String = ""
    var environment: String = ""
    var workingDirectory: String = ""
    var terminal: Bool = false
    var userString: String = ""

    // Ports / Sockets / Mounts
    var ports: [PortEntry] = []
    var sockets: [SocketEntry] = []
    var mounts: [MountEntry] = []

    // Resources
    var cpus: Int = 4
    var memoryGiB: Int = 1

    // Labels / Sysctls
    var labels: [KeyValueEntry] = []
    var sysctls: [KeyValueEntry] = []

    // DNS
    var dnsNameservers: String = ""
    var dnsDomain: String = ""
    var dnsSearchDomains: String = ""
    var dnsOptions: String = ""

    // Toggles
    var rosetta: Bool = false
    var readOnly: Bool = false
    var virtualization: Bool = false
    var ssh: Bool = false
    var autoRemove: Bool = true

    // Status
    var isCreating: Bool = false
    var error: String?
    var success: Bool = false

    private var didBootstrapSelection = false
    private var nameWasCustomized = false
    private var commandWasCustomized = false
    private var environmentWasCustomized = false
    private var workingDirectoryWasCustomized = false
    private var userWasCustomized = false

    private var imageDefaultArguments: [String] = []
    private var imageDefaultEnvironment: [String] = []
    private var imageDefaultWorkingDirectory: String = ""
    private var imageDefaultUser: String = ""

    var availableImageHasDefaultCommand: Bool {
        !imageDefaultArguments.isEmpty
    }

    var defaultCommandPreview: String {
        shellJoin(imageDefaultArguments)
    }

    var imageValidationMessage: String? {
        selectedImageID == nil ? String(localized: "Select an image.") : nil
    }

    var nameValidationMessage: String? {
        let trimmedName = name.trimmed
        guard !trimmedName.isEmpty else {
            return String(localized: "Enter a container name.")
        }
        if ContainersStore.shared.containers.contains(where: { $0.id == trimmedName }) {
            return String(localized: "A container with this name already exists.")
        }
        return nil
    }

    var commandValidationMessage: String? {
        guard selectedImageID != nil else { return nil }

        if useImageDefaultCommand {
            return availableImageHasDefaultCommand
                ? nil
                : String(localized: "This image doesn’t provide a default command. Enter an executable.")
        }

        return executable.trimmed.isEmpty ? String(localized: "Enter an executable.") : nil
    }

    var environmentValidationMessage: String? {
        let invalidLine = parsedEnvironmentLines.first(where: { !$0.contains("=") })
        guard invalidLine != nil else { return nil }
        return String(localized: "Environment values must use KEY=value format.")
    }

    var portValidationMessage: String? {
        var seenMappings = Set<String>()

        for entry in ports where !entry.isBlank {
            guard !entry.hostPort.trimmed.isEmpty, !entry.containerPort.trimmed.isEmpty else {
                return String(localized: "Port mappings need both a host and container port.")
            }
            guard let hostPort = UInt16(entry.hostPort.trimmed), hostPort > 0,
                  let containerPort = UInt16(entry.containerPort.trimmed), containerPort > 0 else {
                return String(localized: "Ports must be numbers between 1 and 65535.")
            }

            let key = "\(hostPort)-\(entry.proto.rawValue)"
            if !seenMappings.insert(key).inserted {
                return String(localized: "Each host port can only be published once per protocol.")
            }
            _ = containerPort
        }

        return nil
    }

    var mountValidationMessage: String? {
        for entry in mounts where !entry.isBlank {
            guard !entry.destination.trimmed.isEmpty else {
                return String(localized: "Every mount needs a destination path in the container.")
            }

            switch entry.type {
            case .bind, .volume:
                guard !entry.source.trimmed.isEmpty else {
                    return String(localized: "Folder and volume mounts need a source.")
                }
            case .tmpfs:
                break
            }
        }

        return nil
    }

    var socketValidationMessage: String? {
        for entry in sockets where !entry.isBlank {
            guard !entry.hostPath.trimmed.isEmpty, !entry.containerPath.trimmed.isEmpty else {
                return String(localized: "Socket forwards need both host and container paths.")
            }
        }
        return nil
    }

    var validationMessage: String? {
        imageValidationMessage
            ?? nameValidationMessage
            ?? commandValidationMessage
            ?? environmentValidationMessage
            ?? portValidationMessage
            ?? mountValidationMessage
            ?? socketValidationMessage
    }

    var canRun: Bool {
        selectedImageID != nil && validationMessage == nil && !isCreating
    }

    func bootstrapSelection(initialImageID: String?, fallbackImageID: String?) {
        guard !didBootstrapSelection else { return }
        if let imageID = initialImageID ?? fallbackImageID {
            didBootstrapSelection = true
            selectImage(imageID)
        }
    }

    func selectImage(_ imageID: String?) {
        selectedImageID = imageID
        clearStatus()
        applyImageDefaults()
    }

    func updateName(_ value: String) {
        name = value
        nameWasCustomized = true
        clearStatus()
    }

    func updateUseImageDefaultCommand(_ value: Bool) {
        useImageDefaultCommand = value
        commandWasCustomized = true
        clearStatus()
    }

    func updateExecutable(_ value: String) {
        executable = value
        commandWasCustomized = true
        clearStatus()
    }

    func updateArguments(_ value: String) {
        arguments = value
        commandWasCustomized = true
        clearStatus()
    }

    func updateEnvironment(_ value: String) {
        environment = value
        environmentWasCustomized = true
        clearStatus()
    }

    func updateWorkingDirectory(_ value: String) {
        workingDirectory = value
        workingDirectoryWasCustomized = true
        clearStatus()
    }

    func updateUserString(_ value: String) {
        userString = value
        userWasCustomized = true
        clearStatus()
    }

    func addPort() {
        ports.append(PortEntry())
    }

    func addBindMount() {
        mounts.append(MountEntry(type: .bind))
    }

    func addVolumeMount() {
        mounts.append(MountEntry(type: .volume))
    }

    func addTmpfsMount() {
        mounts.append(MountEntry(type: .tmpfs))
    }

    func addSocket() {
        sockets.append(SocketEntry())
    }

    @MainActor
    func run() async {
        if let validationMessage {
            error = validationMessage
            success = false
            return
        }

        guard let imageID = selectedImageID,
              let image = ImagesStore.shared.images.first(where: { $0.id == imageID }),
              let clientImage = image.image else {
            error = String(localized: "No image selected or image not available")
            return
        }

        isCreating = true
        error = nil
        success = false

        do {
            let processConfig = try buildProcessConfiguration()
            let containerName = name.trimmed

            var config = ContainerConfiguration(
                id: containerName,
                image: clientImage.description,
                process: processConfig
            )

            config.publishedPorts = try buildPublishedPorts()
            config.publishedSockets = buildPublishedSockets()
            config.mounts = buildMounts()

            if let selectedNetworkID = selectedNetworkID?.trimmed, !selectedNetworkID.isEmpty {
                config.networks = [
                    AttachmentConfiguration(
                        network: selectedNetworkID,
                        options: AttachmentOptions(hostname: containerName)
                    )
                ]
            }

            let labelPairs = labels.filter { !$0.key.trimmed.isEmpty }
            if !labelPairs.isEmpty {
                config.labels = Dictionary(
                    labelPairs.map { ($0.key.trimmed, $0.value) },
                    uniquingKeysWith: { _, last in last }
                )
            }

            let sysctlPairs = sysctls.filter { !$0.key.trimmed.isEmpty }
            if !sysctlPairs.isEmpty {
                config.sysctls = Dictionary(
                    sysctlPairs.map { ($0.key.trimmed, $0.value) },
                    uniquingKeysWith: { _, last in last }
                )
            }

            if hasAnyDNSOverride {
                config.dns = ContainerConfiguration.DNSConfiguration(
                    nameservers: commaSeparatedValues(from: dnsNameservers).isEmpty
                        ? ContainerConfiguration.DNSConfiguration.defaultNameservers
                        : commaSeparatedValues(from: dnsNameservers),
                    domain: dnsDomain.trimmed.isEmpty ? nil : dnsDomain.trimmed,
                    searchDomains: commaSeparatedValues(from: dnsSearchDomains),
                    options: commaSeparatedValues(from: dnsOptions)
                )
            }

            var resources = ContainerConfiguration.Resources()
            resources.cpus = cpus
            resources.memoryInBytes = UInt64(memoryGiB).gib()
            config.resources = resources

            config.rosetta = rosetta
            config.readOnly = readOnly
            config.virtualization = virtualization
            config.ssh = ssh

            let options = ContainerCreateOptions(autoRemove: autoRemove)
            let containerClient = ContainerClient()
            try await containerClient.create(
                configuration: config,
                options: options,
                kernel: try await ClientKernel.getDefaultKernel(for: .current)
            )

            if !autoRemove {
                AppSettings.addPersistentContainerID(containerName)
            }

            RefreshCoordinator.shared.containerMutated()
            success = true
        } catch {
            self.error = error.localizedDescription
            AppViewModel.shared.showError(.containerCreateFailed(error.localizedDescription))
        }

        isCreating = false
    }

    private func clearStatus() {
        error = nil
        success = false
    }

    private func applyImageDefaults() {
        imageDefaultArguments = []
        imageDefaultEnvironment = []
        imageDefaultWorkingDirectory = ""
        imageDefaultUser = ""

        guard let imageID = selectedImageID else {
            if !nameWasCustomized { name = "" }
            if !commandWasCustomized {
                useImageDefaultCommand = true
                executable = ""
                arguments = ""
            }
            if !environmentWasCustomized { environment = "" }
            if !workingDirectoryWasCustomized { workingDirectory = "" }
            if !userWasCustomized { userString = "" }
            return
        }

        if !nameWasCustomized || name.trimmed.isEmpty {
            name = suggestedName(for: imageID)
        }

        guard let config = ImagesStore.shared.images.first(where: { $0.id == imageID })?.imageConfiguration?.config else {
            if !commandWasCustomized {
                useImageDefaultCommand = false
                executable = ""
                arguments = ""
            }
            if !environmentWasCustomized { environment = "" }
            if !workingDirectoryWasCustomized { workingDirectory = "" }
            if !userWasCustomized { userString = "" }
            return
        }

        imageDefaultArguments = (config.entrypoint ?? []) + (config.cmd ?? [])
        imageDefaultEnvironment = config.env ?? []
        imageDefaultWorkingDirectory = config.workingDir ?? ""
        imageDefaultUser = config.user ?? ""

        if !commandWasCustomized {
            useImageDefaultCommand = !imageDefaultArguments.isEmpty
            executable = imageDefaultArguments.first ?? ""
            arguments = shellJoin(Array(imageDefaultArguments.dropFirst()))
        }
        if !environmentWasCustomized {
            environment = imageDefaultEnvironment.joined(separator: "\n")
        }
        if !workingDirectoryWasCustomized {
            workingDirectory = imageDefaultWorkingDirectory
        }
        if !userWasCustomized {
            userString = imageDefaultUser
        }
    }

    private func suggestedName(for imageID: String) -> String {
        let withoutDigest = imageID.split(separator: "@").first.map(String.init) ?? imageID
        let lastPathComponent = withoutDigest.split(separator: "/").last.map(String.init) ?? withoutDigest
        let sanitized = lastPathComponent
            .lowercased()
            .replacingOccurrences(of: ":", with: "-")
            .map { char -> Character in
                if char.isLetter || char.isNumber || char == "-" || char == "_" || char == "." {
                    return char
                }
                return "-"
            }
        let base = String(sanitized)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-."))
        let resolvedBase = base.isEmpty ? "container" : base

        let existingNames = Set(ContainersStore.shared.containers.map(\.id))
        if !existingNames.contains(resolvedBase) {
            return resolvedBase
        }

        var suffix = 2
        while existingNames.contains("\(resolvedBase)-\(suffix)") {
            suffix += 1
        }
        return "\(resolvedBase)-\(suffix)"
    }

    private func buildProcessConfiguration() throws -> ProcessConfiguration {
        let processArguments: [String]
        if useImageDefaultCommand {
            processArguments = imageDefaultArguments
        } else {
            processArguments = [executable.trimmed] + shellSplit(arguments)
        }

        guard let executable = processArguments.first, !executable.isEmpty else {
            throw RunContainerFormError(String(localized: "Enter an executable."))
        }

        let finalEnvironment = environmentWasCustomized ? parsedEnvironmentLines : imageDefaultEnvironment
        let resolvedWorkingDirectory = workingDirectoryWasCustomized
            ? (workingDirectory.trimmed.isEmpty ? "/" : workingDirectory.trimmed)
            : (imageDefaultWorkingDirectory.isEmpty ? "/" : imageDefaultWorkingDirectory)
        let resolvedUserString = userWasCustomized ? userString.trimmed : imageDefaultUser.trimmed
        let user: ProcessConfiguration.User = resolvedUserString.isEmpty
            ? .id(uid: 0, gid: 0)
            : .raw(userString: resolvedUserString)

        return ProcessConfiguration(
            executable: executable,
            arguments: Array(processArguments.dropFirst()),
            environment: finalEnvironment,
            workingDirectory: resolvedWorkingDirectory,
            terminal: terminal,
            user: user
        )
    }

    private func buildPublishedPorts() throws -> [PublishPort] {
        try ports.compactMap { entry -> PublishPort? in
            guard !entry.isBlank else { return nil }
            guard let hostPort = UInt16(entry.hostPort.trimmed),
                  let containerPort = UInt16(entry.containerPort.trimmed),
                  let hostAddress = try? IPAddress("0.0.0.0") else {
                throw RunContainerFormError(String(localized: "Ports must be numbers between 1 and 65535."))
            }

            return PublishPort(
                hostAddress: hostAddress,
                hostPort: hostPort,
                containerPort: containerPort,
                proto: entry.proto,
                count: 1
            )
        }
    }

    private func buildPublishedSockets() -> [PublishSocket] {
        sockets.compactMap { entry in
            guard !entry.isBlank else { return nil }
            return PublishSocket(
                containerPath: URL(fileURLWithPath: entry.containerPath.trimmed),
                hostPath: URL(fileURLWithPath: entry.hostPath.trimmed)
            )
        }
    }

    private func buildMounts() -> [Filesystem] {
        mounts.compactMap { entry in
            guard !entry.isBlank else { return nil }
            let options = entry.readOnly ? ["ro"] : []

            switch entry.type {
            case .bind:
                return Filesystem.virtiofs(
                    source: entry.source.trimmed,
                    destination: entry.destination.trimmed,
                    options: options
                )
            case .volume:
                return Filesystem.volume(
                    name: entry.source.trimmed,
                    format: "raw",
                    source: entry.source.trimmed,
                    destination: entry.destination.trimmed,
                    options: options
                )
            case .tmpfs:
                return Filesystem.tmpfs(
                    destination: entry.destination.trimmed,
                    options: options
                )
            }
        }
    }

    private var parsedEnvironmentLines: [String] {
        environment
            .split(separator: "\n")
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
    }

    private var hasAnyDNSOverride: Bool {
        !dnsNameservers.trimmed.isEmpty
            || !dnsDomain.trimmed.isEmpty
            || !dnsSearchDomains.trimmed.isEmpty
            || !dnsOptions.trimmed.isEmpty
    }

    private func commaSeparatedValues(from value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func shellSplit(_ input: String) -> [String] {
        var values: [String] = []
        var current = ""
        var isEscaping = false
        var quote: Character?

        for char in input {
            if isEscaping {
                current.append(char)
                isEscaping = false
                continue
            }

            if char == "\\" && quote != "'" {
                isEscaping = true
                continue
            }

            if char == "\"" || char == "'" {
                if quote == char {
                    quote = nil
                } else if quote == nil {
                    quote = char
                } else {
                    current.append(char)
                }
                continue
            }

            if char.isWhitespace && quote == nil {
                if !current.isEmpty {
                    values.append(current)
                    current = ""
                }
                continue
            }

            current.append(char)
        }

        if !current.isEmpty {
            values.append(current)
        }

        return values
    }

    private func shellJoin(_ values: [String]) -> String {
        values.map { value in
            if value.contains(where: { $0.isWhitespace || $0 == "\"" || $0 == "'" }) {
                let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
                return "\"\(escaped)\""
            }
            return value
        }
        .joined(separator: " ")
    }
}

private struct RunContainerFormError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension PortEntry {
    var isBlank: Bool {
        hostPort.trimmed.isEmpty && containerPort.trimmed.isEmpty
    }
}

private extension SocketEntry {
    var isBlank: Bool {
        hostPath.trimmed.isEmpty && containerPath.trimmed.isEmpty
    }
}

private extension MountEntry {
    var isBlank: Bool {
        switch type {
        case .bind, .volume:
            return source.trimmed.isEmpty && destination.trimmed.isEmpty
        case .tmpfs:
            return destination.trimmed.isEmpty
        }
    }
}
