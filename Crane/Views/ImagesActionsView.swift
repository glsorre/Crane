import ContainerAPIClient
import ContainerizationOCI
import SwiftUI

struct ImagesActionsView: View {
    @SwiftUI.State var image: Image
    @SwiftUI.State private var runSheetIsVisible = false
    @SwiftUI.State private var tagSheetIsVisible = false

    var body: some View {
        Group {
            if image.status == .available {
                HStack(spacing: 4) {
                    Button {
                        runSheetIsVisible = true
                    } label: {
                        SwiftUI.Image(systemName: "play.fill")
                            .font(Font.system(size: 11))
                    }
                    .buttonStyle(.glass)
                    .frame(width: 50)

                    // Secondary: borderless + muted tint so tag does not compete with primary run.
                    Button {
                        tagSheetIsVisible = true
                    } label: {
                        SwiftUI.Image(systemName: "tag.fill")
                            .font(Font.system(size: 11))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.borderless)
                    .frame(width: 50)
                    .help(String(localized: "imageTagSheetTitle"))

                    SpinnerButton(isLoading: image.status == .removing) {
                        Task {
                            try await ImagesStore.shared.removeImage(reference: image.id)
                        }
                    } label: {
                        SwiftUI.Image(systemName: "trash.fill")
                            .font(Font.system(size: 11))
                    }
                    .buttonStyle(.glass)
                    .foregroundColor(Color(.systemRed))
                    .frame(width: 50)
                }
            } else if image.status == .tagging {
                ProgressView()
                    .progressViewStyle(.linear)
            } else if image.status == .fetching {
                ProgressView()
                    .progressViewStyle(.linear)
            } else if image.status == .removing {
                ProgressView()
                    .background(Color(.systemRed))
                    .progressViewStyle(.linear)
            }
        }
        .sheet(isPresented: $runSheetIsVisible) {
            ContainerRunView(isPresented: $runSheetIsVisible, initialImageID: image.id)
        }
        .sheet(isPresented: $tagSheetIsVisible) {
            ImageTagRenameView(isPresented: $tagSheetIsVisible, sourceReference: image.id)
        }
    }
}
