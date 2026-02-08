import ContainerAPIClient
import ContainerResource
import ContainerizationOCI
import SwiftUI

struct ContainerCreateFormView: View {
    var image: Image
    @Binding var isPresented: Bool

    @SwiftUI.State private var name: String = ""
    @SwiftUI.State private var executable: String = ""
    @SwiftUI.State private var arguments: String = ""
    @SwiftUI.State private var environment: String = ""
    @SwiftUI.State private var selectedNetworks: Set<String> = []
    @SwiftUI.State private var autoRemove: Bool = true
    @SwiftUI.State private var isCreating: Bool = false

    private var isDisabled: Bool {
        name.isEmpty || executable.isEmpty
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            Form {
                TextField("createContainerName", text: $name)
                TextField("createContainerExecutable", text: $executable, prompt: Text(image.imageConfiguration?.config?.entrypoint?.joined(separator: " ") ?? ""))
                TextField("createContainerExecutableArguments", text: $arguments, prompt: Text(image.imageConfiguration?.config?.cmd?.joined(separator: " ") ?? ""))
                TextField("createContainerEnvironment", text: $environment, axis: .vertical)
                    .lineLimit(5...10)
                Toggle("createContainerAutoRemove", isOn: $autoRemove)
                LabeledContent("createContainerNetworks") {
                    VStack {
                        ForEach(Array(NetworksStore.shared.networks), id: \.id) { network in
                            Toggle(isOn: Binding(
                                get: { selectedNetworks.contains(network.id) },
                                set: { isSelected in
                                    if isSelected { selectedNetworks.insert(network.id) }
                                    else { selectedNetworks.remove(network.id) }
                                }
                            )) {
                                Text(network.id)
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 400, alignment: .topLeading)
            SpinnerButton(isLoading: isCreating, action: {
                Task { @MainActor in
                    isCreating = true
                    let executableArgs = executable.split(separator: " ").map { String($0) }
                    let environmentVars = environment.split(separator: "\n").map { String($0) }
                    let networks = NetworksStore.shared.networks.filter { selectedNetworks.contains($0.id) }
                    do {
                        try await image.createContainer(
                            id: name,
                            executable: executable,
                            arguments: executableArgs,
                            environment: environmentVars,
                            networks: Array(networks),
                            autoRemove: autoRemove
                        )
                        isPresented = false
                    } catch {
                        AppViewModel.shared.showError(.containerStartFailed(error.localizedDescription))
                    }
                    isCreating = false
                }
            }) {
                Text("createContainerFromImage")
            }
            .buttonStyle(.glassProminent)
            .disabled(isDisabled)
        }
        .padding(Spacing.sm)
    }
}
