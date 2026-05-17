import ContainerAPIClient
import ContainerizationOCI
import SwiftUI

struct ImagesActionsView: View {
    let image: Image
    @SwiftUI.State private var runSheetIsVisible = false
    @SwiftUI.State private var tagSheetIsVisible = false

    var body: some View {
        Group {
            if image.status == .available {
                HStack(spacing: 4) {
                    RowActionButton(
                        .primary,
                        action: { runSheetIsVisible = true },
                        label: {
                            SwiftUI.Image(systemName: "play.fill")
                        }
                    )

                    RowActionButton(
                        .destructive,
                        isLoading: image.status == .removing,
                        action: {
                            Task {
                                do {
                                    try await ImagesStore.shared.removeImage(reference: image.id)
                                } catch {
                                    AppViewModel.shared.showError(.imageRemoveFailed(error.localizedDescription))
                                }
                            }
                        },
                        label: {
                            SwiftUI.Image(systemName: "trash.fill")
                        }
                    )

                    RowActionButton(
                        .tertiary,
                        help: String(localized: "imageTagSheetTitle"),
                        action: { tagSheetIsVisible = true },
                        label: {
                            SwiftUI.Image(systemName: "tag.fill")
                        }
                    )
                }
            } else if image.status == .tagging || image.status == .fetching {
                ProgressView()
                    .progressViewStyle(.linear)
                    .frame(width: 158)
            } else if image.status == .removing {
                ProgressView()
                    .progressViewStyle(.linear)
                    .frame(width: 158)
                    .background(Color(.systemRed))
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
