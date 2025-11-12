//
//  NumericField.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import AppKit
import SwiftUI

struct NumericField: NSViewRepresentable {
    @Binding var value: Int  // Added: Bind the numeric value to enable two-way sync.
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.minimumIntegerDigits = 1
        formatter.maximumIntegerDigits = 2
        formatter.minimum = 1
        formatter.maximum = 60
        formatter.positiveSuffix = "s"
        textField.formatter = formatter
        
        textField.isEditable = true
        
        // Added: Set target/action for handling edits.
        textField.target = context.coordinator
        textField.action = #selector(Coordinator.valueChanged(_:))
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Added: Sync the text field's value from the SwiftUI binding.
        nsView.integerValue = value
    }
    
    func makeCoordinator() -> Coordinator {
        // Added: Create coordinator for handling edits.
        Coordinator(self)
    }
    
    // Added: Coordinator to handle text field changes and update the binding.
    class Coordinator: NSObject {
        var parent: NumericField
        
        init(_ parent: NumericField) {
            self.parent = parent
        }
        
        @objc func valueChanged(_ sender: NSTextField) {
            parent.value = sender.integerValue
            // You could extend here to interact with logs/scrolling (e.g., trigger log refresh on value change).
        }
    }
}

