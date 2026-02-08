import ContainerAPIClient
import ContainerizationOCI
import SwiftUI

struct ImagesActionsView: View {
    @SwiftUI.State var image: Image
    @SwiftUI.State private var runSheetIsVisible = false

    var body: some View {
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
                .sheet(isPresented: $runSheetIsVisible) {
                    ContainerRunView(isPresented: $runSheetIsVisible, initialImageID: image.id)
                }

                SpinnerButton(isLoading: image.status != .available) {
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
