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
    @SwiftUI.State private var isCreating: Bool = false

    private var isDisabled: Bool {
        name.isEmpty || executable.isEmpty
    }

    var body: some View {
        VStack(spacing: 20) {
            Form {
                TextField("createContainerName", text: $name)
                    .textFieldStyle(.roundedBorder)
                TextField("createContainerExecutable", text: $executable, prompt: Text(image.imageConfiguration?.config?.entrypoint?.joined(separator: " ") ?? ""))
                    .textFieldStyle(.roundedBorder)
                TextField("createContainerExecutableArguments", text: $arguments, prompt: Text(image.imageConfiguration?.config?.cmd?.joined(separator: " ") ?? ""))
                    .textFieldStyle(.roundedBorder)
                TextField("createContainerEnvironment", text: $environment, axis: .vertical)
                    .lineLimit(5...10)
                    .textFieldStyle(.roundedBorder)
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
                            networks: Array(networks)
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
            .buttonStyle(.borderedProminent)
            .disabled(isDisabled)
        }
        .padding()
    }
}
