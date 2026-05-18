//
//  DockerfileEditor.swift
//  Crane
//

import AppKit
import Highlightr
import SwiftUI

struct DockerfileEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.delegate = context.coordinator

        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]

        if let highlightr = context.coordinator.highlightr {
            textView.backgroundColor = highlightr.theme.themeBackgroundColor
        }

        if let highlightr = context.coordinator.highlightr,
            let highlighted = highlightr.highlight(text, as: "dockerfile")
        {
            textView.textStorage?.setAttributedString(highlighted)
        } else {
            textView.string = text
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text && !context.coordinator.isEditing {
            context.coordinator.isUpdating = true
            if let highlightr = context.coordinator.highlightr,
                let highlighted = highlightr.highlight(text, as: "dockerfile")
            {
                textView.textStorage?.setAttributedString(highlighted)
            } else {
                textView.string = text
            }
            context.coordinator.isUpdating = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DockerfileEditor
        var highlightr: Highlightr?
        var isUpdating = false
        var isEditing = false

        init(_ parent: DockerfileEditor) {
            self.parent = parent
            self.highlightr = Highlightr()
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            self.highlightr?.setTheme(to: isDark ? "xcode-dark" : "xcode")
            super.init()
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating else { return }
            guard let textView = notification.object as? NSTextView else { return }
            isEditing = true
            parent.text = textView.string

            if let highlightr = highlightr,
                let highlighted = highlightr.highlight(textView.string, as: "dockerfile")
            {
                let selectedRange = textView.selectedRange()
                isUpdating = true
                textView.textStorage?.setAttributedString(highlighted)
                textView.setSelectedRange(selectedRange)
                isUpdating = false
            }
            isEditing = false
        }
    }
}
