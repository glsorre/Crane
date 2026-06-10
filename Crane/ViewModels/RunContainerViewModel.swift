// swiftlint:disable file_length
// `RunContainerViewModel` aggregates form bindings, validation, and the
// async run pipeline for the Run Container dialog; splitting it would
// scatter tightly-coupled @MainActor state across several files.

import ContainerAPIClient
import ContainerResource
import ContainerizationExtras
import ContainerizationOCI
import ContainerizationOS
import Foundation
import Observation
import SystemPackage
import os.log

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
// swiftlint:disable:next type_body_length
class RunContainerViewModel {
    let stores: CraneStores

    init(stores: CraneStores) {
        self.stores = stores
    }

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

    private var validator: RunContainerValidator {
        RunContainerValidator(
            selectedImageID: selectedImageID,
            name: name,
            useImageDefaultCommand: useImageDefaultCommand,
            imageHasDefaultCommand: availableImageHasDefaultCommand,
            executable: executable,
            environment: environment,
            ports: ports,
            mounts: mounts,
            sockets: sockets,
            nameInUse: { [stores] trimmed in stores.containers.containers.contains { $0.id == trimmed } }
        )
    }

    var imageValidationMessage: String? { validator.imageValidationMessage }
    var nameValidationMessage: String? { validator.nameValidationMessage }
    var commandValidationMessage: String? { validator.commandValidationMessage }
    var environmentValidationMessage: String? { validator.environmentValidationMessage }
    var portValidationMessage: String? { validator.portValidationMessage }
    var mountValidationMessage: String? { validator.mountValidationMessage }
    var socketValidationMessage: String? { validator.socketValidationMessage }
    var validationMessage: String? { validator.validationMessage }
    var canRun: Bool { validator.canRun }

    func bootstrapSelection(initialImageID: String?, fallbackImageID: String?) {
        guard !didBootstrapSelection else { return }
        if let imageID = initialImageID ?? fallbackImageID {
            didBootstrapSelection = true
            selectImage(imageID)
        }
    }

    func selectImage(_ imageID: String?) {
        selectedImageID = imageID
        applyImageDefaults()
        refreshImageConfigurationIfNeeded(for: imageID)
    }

    private func refreshImageConfigurationIfNeeded(for imageID: String?) {
        guard let imageID,
            let image = stores.images.images.first(where: { $0.id == imageID }),
            image.imageConfiguration?.config == nil,
            let clientImage = image.image
        else { return }

        Task { @MainActor [weak self, weak image] in
            guard let image else { return }
            try? await image.setImage(image: clientImage)
            guard let self, self.selectedImageID == imageID else { return }
            self.applyImageDefaults()
        }
    }

    func updateName(_ value: String) {
        name = value
        nameWasCustomized = true
    }

    func updateUseImageDefaultCommand(_ value: Bool) {
        useImageDefaultCommand = value
        commandWasCustomized = true
    }

    func updateExecutable(_ value: String) {
        executable = value
        commandWasCustomized = true
    }

    func updateArguments(_ value: String) {
        arguments = value
        commandWasCustomized = true
    }

    func updateEnvironment(_ value: String) {
        environment = value
        environmentWasCustomized = true
    }

    func updateWorkingDirectory(_ value: String) {
        workingDirectory = value
        workingDirectoryWasCustomized = true
    }

    func updateUserString(_ value: String) {
        userString = value
        userWasCustomized = true
    }

    @discardableResult
    func addPort() -> UUID {
        let entry = PortEntry()
        ports.append(entry)
        return entry.id
    }

    @discardableResult
    func addBindMount() -> UUID {
        let entry = MountEntry(type: .bind)
        mounts.append(entry)
        return entry.id
    }

    @discardableResult
    func addVolumeMount() -> UUID {
        let entry = MountEntry(type: .volume)
        mounts.append(entry)
        return entry.id
    }

    @discardableResult
    func addTmpfsMount() -> UUID {
        let entry = MountEntry(type: .tmpfs)
        mounts.append(entry)
        return entry.id
    }

    @discardableResult
    func addSocket() -> UUID {
        let entry = SocketEntry()
        sockets.append(entry)
        return entry.id
    }

    @MainActor
    // swiftlint:disable:next function_body_length
    func run() async throws {
        if let validationMessage {
            throw RunContainerFormError(validationMessage)
        }

        guard let imageID = selectedImageID,
            let image = stores.images.images.first(where: { $0.id == imageID }),
            let clientImage = image.image
        else {
            throw RunContainerFormError(String(localized: "No image selected or image not available"))
        }

        let processConfig: ProcessConfiguration
        let containerName = name.trimmed
        var config: ContainerConfiguration
        // Runtime auto-remove is disabled so Crane can inspect early exits before
        // the container disappears. The user toggle is honored by Crane-side
        // bookkeeping (AppSettings.persistentContainerIDs) plus a watcher task
        // that performs the deletion after a clean exit.
        let options = ContainerCreateOptions(autoRemove: false)
        let containerClient = ContainerClient()

        processConfig = try buildProcessConfiguration()
        config = ContainerConfiguration(
            id: containerName,
            image: clientImage.description,
            process: processConfig
        )

        config.publishedPorts = try buildPublishedPorts()
        config.publishedSockets = try buildPublishedSockets()
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

        try await containerClient.create(
            configuration: config,
            options: options,
            kernel: try await ClientKernel.getDefaultKernel(for: .current)
        )

        if !autoRemove {
            AppSettings.addPersistentContainerID(containerName)
        }

        do {
            try await withTimeout {
                let io = try ProcessIO.create(tty: true, interactive: false, detach: true)
                defer {
                    _ = try? io.close()
                }
                let process = try await containerClient.bootstrap(id: containerName, stdio: io.stdio)
                try await process.start()
            }
        } catch {
            Log.run.error("bootstrap/start failed for \(containerName): \(error.localizedDescription, privacy: .public)")
            AppSettings.removePersistentContainerID(containerName)
            CraneMutationBus.postContainerMutated()
            throw error
        }

        let exitedDuringWatch = await Self.watchForEarlyExit(
            client: containerClient,
            id: containerName
        )

        if exitedDuringWatch {
            let tail = await Self.fetchLogTail(
                client: containerClient,
                id: containerName,
                maxLines: 40
            )
            AppSettings.removePersistentContainerID(containerName)
            try? await containerClient.delete(id: containerName)
            CraneMutationBus.postContainerMutated()

            let baseMessage = String(
                localized: "runContainerExitedEarly",
                defaultValue: "Container exited shortly after starting. Check the command, arguments, and environment."
            )
            let combined = tail.isEmpty ? baseMessage : "\(baseMessage)\n\n\(tail)"
            Log.run.error("container \(containerName) exited within watch window")
            throw RunContainerFormError(combined)
        }

        if autoRemove {
            Self.scheduleAutoRemove(client: containerClient, id: containerName)
        }

        CraneMutationBus.postContainerMutated()
    }

    nonisolated private static let earlyExitWatchDuration: Duration = .seconds(2)
    nonisolated private static let earlyExitWatchCadence: Duration = .milliseconds(250)
    nonisolated private static let autoRemovePollCadence: Duration = .seconds(1)

    nonisolated private static func watchForEarlyExit(
        client: ContainerClient,
        id: String
    ) async -> Bool {
        let deadline = ContinuousClock.now.advanced(by: earlyExitWatchDuration)
        while ContinuousClock.now < deadline {
            try? await Task.sleep(for: earlyExitWatchCadence)
            guard let snapshots = try? await client.list() else { continue }
            guard let snapshot = snapshots.first(where: { $0.id == id }) else {
                return true
            }
            if snapshot.status != .running {
                return true
            }
        }
        return false
    }

    nonisolated private static func fetchLogTail(
        client: ContainerClient,
        id: String,
        maxLines: Int
    ) async -> String {
        do {
            let handles = try await client.logs(id: id)
            var lines: [String] = []
            let trimWhenAbove = max(maxLines * 4, maxLines + 1)
            let trimDownTo = max(maxLines * 2, maxLines)
            for handle in handles {
                guard let reader = StreamReader(fileHandle: handle) else { continue }
                while let line = reader.nextLine() {
                    lines.append(line)
                    if lines.count > trimWhenAbove {
                        lines.removeFirst(lines.count - trimDownTo)
                    }
                }
            }
            if lines.count > maxLines {
                lines = Array(lines.suffix(maxLines))
            }
            return lines.joined(separator: "\n")
        } catch {
            Log.run.error("fetch log tail failed for \(id): \(error.localizedDescription, privacy: .public)")
            return ""
        }
    }

    nonisolated private static func scheduleAutoRemove(client: ContainerClient, id: String) {
        Task.detached {
            while !Task.isCancelled {
                try? await Task.sleep(for: autoRemovePollCadence)
                guard let snapshots = try? await client.list() else { continue }
                guard let snapshot = snapshots.first(where: { $0.id == id }) else {
                    CraneMutationBus.postContainerMutated()
                    return
                }
                if snapshot.status == .running || snapshot.status == .stopping {
                    continue
                }
                try? await client.delete(id: id)
                CraneMutationBus.postContainerMutated()
                return
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
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

        guard let config = stores.images.images.first(where: { $0.id == imageID })?.imageConfiguration?.config else {
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

    func suggestedName(for imageID: String) -> String {
        let withoutDigest = imageID.split(separator: "@").first.map(String.init) ?? imageID
        let lastPathComponent = withoutDigest.split(separator: "/").last.map(String.init) ?? withoutDigest
        let sanitized =
            lastPathComponent
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

        let existingNames = Set(stores.containers.containers.map(\.id))
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
        let resolvedWorkingDirectory =
            workingDirectoryWasCustomized
            ? (workingDirectory.trimmed.isEmpty ? "/" : workingDirectory.trimmed)
            : (imageDefaultWorkingDirectory.isEmpty ? "/" : imageDefaultWorkingDirectory)
        let resolvedUserString = userWasCustomized ? userString.trimmed : imageDefaultUser.trimmed
        let user: ProcessConfiguration.User =
            resolvedUserString.isEmpty
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
                let hostAddress = try? IPAddress("0.0.0.0")
            else {
                throw RunContainerFormError(String(localized: "Ports must be numbers between 1 and 65535."))
            }

            return try PublishPort(
                hostAddress: hostAddress,
                hostPort: hostPort,
                containerPort: containerPort,
                proto: entry.proto,
                count: 1
            )
        }
    }

    private func buildPublishedSockets() throws -> [PublishSocket] {
        try sockets.compactMap { entry -> PublishSocket? in
            guard !entry.isBlank else { return nil }
            return try PublishSocket(
                containerPath: FilePath(entry.containerPath.trimmed),
                hostPath: FilePath(entry.hostPath.trimmed)
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
                let volumeName = entry.source.trimmed
                let resolvedVolume = stores.volumes.volumes.first(where: { $0.id == volumeName })?.volume
                let resolvedSource = resolvedVolume?.source ?? volumeName
                let resolvedFormat = resolvedVolume?.format ?? "raw"
                return Filesystem.volume(
                    name: volumeName,
                    format: resolvedFormat,
                    source: resolvedSource,
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
        validator.parsedEnvironmentLines
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

    func shellSplit(_ input: String) -> [String] {
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

    func shellJoin(_ values: [String]) -> String {
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

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension PortEntry {
    var isBlank: Bool {
        hostPort.trimmed.isEmpty && containerPort.trimmed.isEmpty
    }
}

extension SocketEntry {
    var isBlank: Bool {
        hostPath.trimmed.isEmpty && containerPath.trimmed.isEmpty
    }
}

extension MountEntry {
    var isBlank: Bool {
        switch type {
        case .bind, .volume:
            return source.trimmed.isEmpty && destination.trimmed.isEmpty
        case .tmpfs:
            return destination.trimmed.isEmpty
        }
    }
}
