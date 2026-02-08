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

    // Process
    var command: String = ""
    var environment: String = ""
    var workingDirectory: String = ""
    var terminal: Bool = false
    var userString: String = ""

    // Networks
    var selectedNetworks: Set<String> = []

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

    func prefillFromImage() {
        guard let imageID = selectedImageID,
              let image = ImagesStore.shared.images.first(where: { $0.id == imageID }),
              let config = image.imageConfiguration?.config else { return }

        let parts = (config.entrypoint ?? []) + (config.cmd ?? [])
        if !parts.isEmpty {
            command = parts.joined(separator: " ")
        }
        if let env = config.env, !env.isEmpty {
            environment = env.joined(separator: "\n")
        }
        if let wd = config.workingDir, !wd.isEmpty {
            workingDirectory = wd
        }
        if let user = config.user, !user.isEmpty {
            userString = user
        }
        if let imageLabels = config.labels, !imageLabels.isEmpty {
            labels = imageLabels.map { KeyValueEntry(key: $0.key, value: $0.value) }
        }
    }

    @MainActor
    func run() async {
        guard let imageID = selectedImageID,
              let image = ImagesStore.shared.images.first(where: { $0.id == imageID }),
              let clientImage = image.image else {
            error = "No image selected or image not available"
            return
        }

        isCreating = true
        error = nil
        success = false

        do {
            // Build ProcessConfiguration
            let envLines = environment.split(separator: "\n").map(String.init)
            let user: ProcessConfiguration.User = userString.isEmpty
                ? .id(uid: 0, gid: 0)
                : .raw(userString: userString)

            let cmdParts = command.split(separator: " ", maxSplits: 1)
            let exe = cmdParts.first.map(String.init) ?? ""
            let args = cmdParts.dropFirst().first.map { $0.split(separator: " ").map(String.init) } ?? []

            let processConfig = ProcessConfiguration(
                executable: exe,
                arguments: args,
                environment: envLines,
                workingDirectory: workingDirectory.isEmpty ? "/" : workingDirectory,
                terminal: terminal,
                user: user
            )

            // Build ContainerConfiguration
            var config = ContainerConfiguration(
                id: name,
                image: clientImage.description,
                process: processConfig
            )

            // Published ports
            config.publishedPorts = ports.compactMap { entry -> PublishPort? in
                guard let hp = UInt16(entry.hostPort),
                      let cp = UInt16(entry.containerPort),
                      let addr = try? IPAddress("0.0.0.0") else { return nil }
                return PublishPort(
                    hostAddress: addr,
                    hostPort: hp,
                    containerPort: cp,
                    proto: entry.proto,
                    count: 1
                )
            }

            // Published sockets
            config.publishedSockets = sockets.compactMap { entry in
                guard !entry.hostPath.isEmpty, !entry.containerPath.isEmpty else { return nil }
                return PublishSocket(
                    containerPath: URL(fileURLWithPath: entry.containerPath),
                    hostPath: URL(fileURLWithPath: entry.hostPath)
                )
            }

            // Mounts
            config.mounts = mounts.compactMap { entry in
                guard !entry.destination.isEmpty else { return nil }
                let opts: [String] = entry.readOnly ? ["ro"] : []
                switch entry.type {
                case .bind:
                    guard !entry.source.isEmpty else { return nil }
                    return Filesystem.virtiofs(
                        source: entry.source,
                        destination: entry.destination,
                        options: opts
                    )
                case .volume:
                    guard !entry.source.isEmpty else { return nil }
                    return Filesystem.volume(
                        name: entry.source,
                        format: "raw",
                        source: entry.source,
                        destination: entry.destination,
                        options: opts
                    )
                case .tmpfs:
                    return Filesystem.tmpfs(
                        destination: entry.destination,
                        options: opts
                    )
                }
            }

            // Networks
            config.networks = NetworksStore.shared.networks
                .filter { selectedNetworks.contains($0.id) }
                .map { AttachmentConfiguration(network: $0.id, options: AttachmentOptions(hostname: $0.id)) }

            // Labels & Sysctls
            config.labels = Dictionary(
                labels.filter { !$0.key.isEmpty }.map { ($0.key, $0.value) },
                uniquingKeysWith: { _, last in last }
            )
            config.sysctls = Dictionary(
                sysctls.filter { !$0.key.isEmpty }.map { ($0.key, $0.value) },
                uniquingKeysWith: { _, last in last }
            )

            // DNS
            let hasAnyDNS = !dnsNameservers.isEmpty || !dnsDomain.isEmpty || !dnsSearchDomains.isEmpty || !dnsOptions.isEmpty
            if hasAnyDNS {
                config.dns = ContainerConfiguration.DNSConfiguration(
                    nameservers: dnsNameservers.isEmpty ? ContainerConfiguration.DNSConfiguration.defaultNameservers : dnsNameservers.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                    domain: dnsDomain.isEmpty ? nil : dnsDomain,
                    searchDomains: dnsSearchDomains.isEmpty ? [] : dnsSearchDomains.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                    options: dnsOptions.isEmpty ? [] : dnsOptions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                )
            }

            // Resources
            var resources = ContainerConfiguration.Resources()
            resources.cpus = cpus
            resources.memoryInBytes = UInt64(memoryGiB).mib() * 1024
            config.resources = resources

            // Toggles
            config.rosetta = rosetta
            config.readOnly = readOnly
            config.virtualization = virtualization
            config.ssh = ssh

            // Create
            let options = ContainerCreateOptions(autoRemove: autoRemove)
            _ = try await ClientContainer.create(
                configuration: config,
                options: options,
                kernel: ClientKernel.getDefaultKernel(for: .current)
            )

            if !autoRemove {
                AppSettings.addPersistentContainerID(name)
            }

            RefreshCoordinator.shared.containerMutated()
            success = true
        } catch {
            self.error = error.localizedDescription
            AppViewModel.shared.showError(.containerCreateFailed(error.localizedDescription))
        }

        isCreating = false
    }
}
