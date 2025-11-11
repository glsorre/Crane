//
//  SelectableLogTextView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 11/11/25.
//

import AppKit
import SwiftUI

struct SelectableLogTextView: NSViewRepresentable {
    @Binding var logs: [String]
    @Binding var userScrolled: Bool
    @Binding var shouldFollow: Bool
    @Binding var forceScroll: Bool
    
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = NSColor.controlTextColor
        textView.backgroundColor = NSColor.gray.withAlphaComponent(0.1)
        // Initial text
        textView.string = logs.joined(separator: "\n")
        // add padding
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.boundsDidChange(_:)), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        
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
        
        let isAtBottom = scrollView.documentVisibleRect.maxY >= scrollView.contentSize.height - 1.0
        
        let newText = logs.joined(separator: "\n")
        let textChanged = textView.string != newText
        
        if textChanged {
            context.coordinator.isUpdating = true  // Flag programmatic update
            textView.string = newText
            context.coordinator.isUpdating = false  // Reset after
            
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
        var isUpdating = false
        
        init(_ parent: SelectableLogTextView) {
            self.parent = parent
            super.init()
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc func boundsDidChange(_ notification: Notification) {
            // Mark as user-scrolled only if user action and currently should follow
            if !isUpdating && parent.shouldFollow {
                parent.userScrolled = true
            }
        }
    }
}

