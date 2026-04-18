import SwiftUI

extension View {
    /// Grouped `Form` in sheets: macOS adds extra leading inset to section bodies vs. headers;
    /// nudge the form so group cards line up with section titles and the dialog footer row.
    /// Set `compensateGroupedBodyInset` to `false` for standalone windows (e.g. Settings) where
    /// the surrounding chrome already defines margins.
    @ViewBuilder
    func groupedDialogFormLayout(compensateGroupedBodyInset: Bool = true) -> some View {
        if compensateGroupedBodyInset {
            self.formStyle(.grouped)
                .padding(.horizontal, 0)
                .padding(.leading, -Spacing.md)
        } else {
            self.formStyle(.grouped)
                .padding(.horizontal, 0)
        }
    }
}
