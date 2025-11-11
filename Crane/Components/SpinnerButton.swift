//
//  SpinnerButton.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 10/11/25.
//

import SwiftUI

struct SpinnerButton<Label: View>: View {
    let isLoading: Bool
    let action: () -> Void
    let label: () -> Label
    let minWidth: CGFloat
    
    init(isLoading: Bool, minWidth: CGFloat = .leastNormalMagnitude, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.isLoading = isLoading
        self.action = action
        self.label = label
        self.minWidth = minWidth
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    AnyView(ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small))
                } else {
                    AnyView(label())
                }
            }
        }
        .disabled(isLoading)
        .frame(minWidth: minWidth)
    }
}
