//
//  SelectableLogTextView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import AppKit
import SwiftUI

struct SelectableLogTextView: NSViewRepresentable {
    @Binding var logs: [String]  // Bound to handleMetadata.logs for updates
    @Binding var userScrolled: Bool  // Optional: Track if user manually scrolled
    @Binding var shouldFollow: Bool  // Whether to auto-scroll to bottom on updates
    @Binding var forceScroll: Bool  // Forces immediate scroll to bottom (e.g., when toggle activated)
    
    func makeNSView(context: Context) -> NSScrollView {
        // Create NSTextView inside NSScrollView for better performance
        let textView = NSTextView()
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        // Configure NSTextView
        textView.isEditable = false  // Read-only for logs
        textView.isSelectable = true  // Enable text selection
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)  // Use monospaced font for logs (fixes visibility/readability)
        textView.textColor = NSColor.controlTextColor
        textView.backgroundColor = NSColor.gray.withAlphaComponent(0.1)
        // Initial text
        textView.string = logs.joined(separator: "\n")
        // add padding
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        // Enable scroll notifications to detect user scrolling
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.boundsDidChange(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        
        // Ensure initial scroll to bottom if following is enabled
        if shouldFollow {
            DispatchQueue.main.async {
                textView.scrollToEndOfDocument(nil)
            }
            userScrolled = false  // Reset, as we just auto-scrolled
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // Check if currently at the bottom (with small tolerance for floating point precision)
        let isAtBottom = scrollView.documentVisibleRect.maxY >= scrollView.contentSize.height - 1.0
        
        let newText = logs.joined(separator: "\n")
        let textChanged = textView.string != newText
        
        // Update text if changed
        if textChanged {
            context.coordinator.isUpdating = true  // Flag programmatic update
            textView.string = newText
            context.coordinator.isUpdating = false  // Reset after
            
            // Auto-scroll if following logs and (was at bottom or forced)
            if shouldFollow && (isAtBottom || forceScroll) {
                DispatchQueue.main.async {  // Ensure on main thread for UI updates
                    textView.scrollToEndOfDocument(nil)
                }
                userScrolled = false  // Reset since we scrolled to bottom
                if forceScroll {
                    forceScroll = false
                }
            }
        }
        
        // Handle force scroll regardless of text change
        if shouldFollow && forceScroll {
            DispatchQueue.main.async {
                textView.scrollToEndOfDocument(nil)
            }
            userScrolled = false
            forceScroll = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: SelectableLogTextView
        var isUpdating = false  // Tracks if update is programmatic
        
        init(_ parent: SelectableLogTextView) {
            self.parent = parent
            super.init()
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)  // Clean up observers
        }
        
        @objc func boundsDidChange(_ notification: Notification) {
            // Mark as user-scrolled only if user action and currently should follow
            if !isUpdating && parent.shouldFollow {
                parent.userScrolled = true
            }
        }
    }
}

