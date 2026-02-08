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
    
    init(isLoading: Bool, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.isLoading = isLoading
        self.action = action
        self.label = label
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                } else {
                    label()
                }
            }
        }
        .disabled(isLoading)
    }
}
