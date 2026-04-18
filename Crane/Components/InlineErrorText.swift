import SwiftUI

struct InlineErrorText: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.orange)
    }
}
