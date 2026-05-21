import SwiftUI

struct InlineErrorText: View {
    let message: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            SwiftUI.Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
            Text(message)
                .font(.caption)
        }
        .foregroundStyle(.red)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
