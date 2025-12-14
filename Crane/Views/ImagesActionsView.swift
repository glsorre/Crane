//
//  ImagesActionsView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 15/11/25.
//

import ContainerClient
import ContainerizationOCI
import SwiftUI

struct ImagesActionsView: View {
    @SwiftUI.State var image: Image
    
    @SwiftUI.State private var createPopupIsVisible: Bool = false
    @SwiftUI.State private var createPopupCreating: Bool = false
    @SwiftUI.State private var createContainerName: String = ""
    @SwiftUI.State private var createContainerExecutable: String = ""
    @SwiftUI.State private var createContainerExecutableArguments: String = ""
    @SwiftUI.State private var createContainerEnvironment: String = ""
    @SwiftUI.State private var createContainerNetworks: [Network] = []
    
    private var createContainerFromImageDisabled: Bool {
        createContainerName.isEmpty || createContainerExecutable.isEmpty
    }
    
    var body: some View {
        if (image.status == .available) {
            HStack {
                Button(action: {
                    createPopupIsVisible.toggle()
                }) {
                    SwiftUI.Image(systemName: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .popover(isPresented: $createPopupIsVisible) {
                    VStack(spacing: 20) {
                        Form {
                            TextField("createContainerName", text: $createContainerName)
                                .textFieldStyle(.roundedBorder)
                            TextField("createContainerExecutable", text: $createContainerExecutable, prompt: Text(image.imageConfiguration?.config?.entrypoint?.joined(separator: " ") ?? ""))
                                .textFieldStyle(.roundedBorder)
                            TextField("createContainerExecutableArguments", text: $createContainerExecutableArguments, prompt: Text(image.imageConfiguration?.config?.cmd?.joined(separator: " ") ?? ""))
                                .textFieldStyle(.roundedBorder)
                            TextField("createContainerEnvironment", text: $createContainerEnvironment, axis: .vertical)
                                .lineLimit(5...10)
                                .textFieldStyle(.roundedBorder)
                            LabeledContent("createContainerNetworks") {
                                VStack {
                                    ForEach(Array(NetworksStore.shared.networks), id: \.id) { network in
                                        let networkBinding = Binding<Bool>(
                                            get: { createContainerNetworks.contains(network) },
                                            set: { isSelected in
                                                if isSelected {
                                                    if !createContainerNetworks.contains(network) {
                                                        createContainerNetworks.append(network)
                                                    }
                                                } else {
                                                    createContainerNetworks.removeAll { $0.id == network.id }
                                                }
                                            }
                                        )
                                        Toggle(isOn: networkBinding) {
                                            Text(network.id)
                                        }
                                            .frame(maxWidth: .infinity, alignment: .topLeading)
                                    }
                                }
                            }
                        }
                        .frame(width: 400, alignment: .topLeading)
                        SpinnerButton(isLoading: createPopupCreating, action: {
                            Task {
                                @MainActor in
                                self.createPopupCreating = true
                                let executableArgs = createContainerExecutable.split(separator: " ").map { String($0) }
                                let environmentVars = createContainerEnvironment.split(separator: "\n").map { String($0) }
                                try await image.createContainer(
                                    id: createContainerName,
                                    executable: createContainerExecutable,
                                    arguments: executableArgs,
                                    environment: environmentVars,
                                    networks: createContainerNetworks
                                )
                                self.createPopupIsVisible.toggle()
                                self.createPopupCreating = false
                            }
                        }) {
                            Text("createContainerFromImage")
                                .toggleStyle(.button)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(createContainerFromImageDisabled)
                    }
                    .padding()
                }
                .frame(width: 50)
                SpinnerButton(isLoading: image.status != .available) {
                    Task {
                        try await ImagesStore.shared.removeImage(reference: image.id)
                    }
                } label: {
                    SwiftUI.Image(systemName: "trash.fill")
                        .font(Font.system(size: 11))
                }
                .buttonStyle(.bordered)
                .foregroundColor(Color(.systemRed))
                .frame(width: 50)
            }
        } else if image.status == .fetching {
            ProgressView()
                .progressViewStyle(.linear)
        } else if image.status == .removing {
            ProgressView()
                .background(Color(.systemRed))
                .progressViewStyle(.linear)
        }
    }
}
