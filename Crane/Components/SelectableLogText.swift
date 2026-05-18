//
//  SelectableLogText.swift
//  Crane
//

import AppKit
import SwiftUI

struct SelectableLogText: NSViewRepresentable {
    var stream: ContainerLogStream

    func makeNSView(context: Context) -> NSScrollView {
        let textView = LogTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.allowsUndo = false
        textView.isRichText = false
        textView.usesFontPanel = false
        textView.usesFindPanel = false
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.layoutManager?.allowsNonContiguousLayout = true
        textView.coordinator = context.coordinator

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.boundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.render(stream: stream, fullRebuild: true)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parentStream = stream
        context.coordinator.render(stream: stream, fullRebuild: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(stream: stream)
    }

    final class Coordinator: NSObject {
        var parentStream: ContainerLogStream
        weak var textView: LogTextView?
        weak var scrollView: NSScrollView?

        // Render bookkeeping
        private var lastStreamId: ObjectIdentifier?
        private var lastRenderedLineId: Int?
        private var lastDroppedCount: Int = 0
        private var lineRanges: [(id: Int, range: NSRange)] = []
        private var matchRanges: [NSRange] = []
        private var lastConfigSignature: String = ""
        private var lastSearchSignature: String = ""
        private var lastCurrentMatch: Int = -1

        init(stream: ContainerLogStream) {
            self.parentStream = stream
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        // MARK: - Public render entrypoint

        func render(stream: ContainerLogStream, fullRebuild: Bool) {
            guard let textView else { return }
            let storage = textView.textStorage!

            let currentId = ObjectIdentifier(stream)
            let streamChanged = currentId != lastStreamId
            lastStreamId = currentId

            if streamChanged {
                lastRenderedLineId = nil
                lastDroppedCount = 0
                lineRanges.removeAll(keepingCapacity: true)
                matchRanges.removeAll(keepingCapacity: true)
                lastConfigSignature = ""
                lastSearchSignature = ""
                lastCurrentMatch = -1
            }

            let configSignature = "\(stream.showTimestamps)|\(stream.showLineNumbers)|\(stream.fontSize)|\(stream.levelFilter.map { $0.rawValue }.sorted().joined(separator: ","))"
            let configChanged = configSignature != lastConfigSignature

            if fullRebuild || configChanged || streamChanged {
                storage.beginEditing()
                storage.setAttributedString(NSAttributedString())
                lineRanges.removeAll(keepingCapacity: true)
                for line in stream.logs where passesFilter(line, stream: stream) {
                    appendLine(line, to: storage, stream: stream)
                }
                storage.endEditing()
                lastRenderedLineId = stream.logs.last?.id
                lastDroppedCount = stream.droppedCount
                lastConfigSignature = configSignature
                applySearchHighlight(stream: stream, force: true)
                scrollToBottomIfFollowing(stream: stream)
                return
            }

            // Detect ring-buffer eviction
            if stream.droppedCount > lastDroppedCount {
                let droppedDelta = stream.droppedCount - lastDroppedCount
                let firstSurvivingId = stream.logs.first?.id ?? stream.nextLogId
                // Drop any rendered line whose id < firstSurvivingId
                var totalDropLen = 0
                while let head = lineRanges.first, head.id < firstSurvivingId {
                    totalDropLen += head.range.length
                    lineRanges.removeFirst()
                }
                if totalDropLen > 0 {
                    storage.beginEditing()
                    storage.replaceCharacters(in: NSRange(location: 0, length: totalDropLen), with: "")
                    storage.endEditing()
                    // Shift remaining ranges
                    for i in lineRanges.indices {
                        lineRanges[i].range.location -= totalDropLen
                    }
                }
                lastDroppedCount = stream.droppedCount
                _ = droppedDelta
            }

            // Incremental append of new lines
            let newLines: ArraySlice<ContainerLogLine>
            if let last = lastRenderedLineId,
               let firstNewIdx = stream.logs.firstIndex(where: { $0.id > last }) {
                newLines = stream.logs[firstNewIdx...]
            } else if lastRenderedLineId == nil {
                newLines = stream.logs[stream.logs.startIndex...]
            } else {
                newLines = stream.logs.suffix(0)
            }

            if !newLines.isEmpty {
                storage.beginEditing()
                for line in newLines where passesFilter(line, stream: stream) {
                    appendLine(line, to: storage, stream: stream)
                }
                storage.endEditing()
                lastRenderedLineId = stream.logs.last?.id
                applySearchHighlight(stream: stream, force: false)
                scrollToBottomIfFollowing(stream: stream)
            }

            // Search query change (without new lines)
            applySearchHighlight(stream: stream, force: false)

            // Current match navigation
            if stream.currentMatchIndex != lastCurrentMatch {
                lastCurrentMatch = stream.currentMatchIndex
                scrollToCurrentMatch(stream: stream)
            }

            if stream.forceScroll {
                textView.scrollToEndOfDocument(nil)
                stream.forceScroll = false
            }
        }

        // MARK: - Filtering

        private func passesFilter(_ line: ContainerLogLine, stream: ContainerLogStream) -> Bool {
            if stream.levelFilter.isEmpty { return true }
            guard let level = line.level else {
                // No detected level: show only when filter is otherwise inactive
                return false
            }
            return stream.levelFilter.contains(level)
        }

        // MARK: - Line rendering

        private func appendLine(_ line: ContainerLogLine, to storage: NSTextStorage, stream: ContainerLogStream) {
            let font = NSFont.monospacedSystemFont(ofSize: stream.fontSize, weight: .regular)
            let parts = NSMutableAttributedString()

            if stream.showLineNumbers {
                let prefix = LogLineFormatter.lineNumberPrefix(line.id) + "  "
                parts.append(NSAttributedString(string: prefix, attributes: [
                    .font: font,
                    .foregroundColor: NSColor.tertiaryLabelColor,
                ]))
            }
            if stream.showTimestamps {
                let prefix = LogLineFormatter.timestampPrefix(for: line.arrivedAt) + "  "
                parts.append(NSAttributedString(string: prefix, attributes: [
                    .font: font,
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]))
            }

            let body = line.message + "\n"
            parts.append(NSAttributedString(string: body, attributes: [
                .font: font,
                .foregroundColor: LogLineFormatter.color(for: line.level),
            ]))

            let location = storage.length
            storage.append(parts)
            lineRanges.append((id: line.id, range: NSRange(location: location, length: parts.length)))
        }

        // MARK: - Search

        private func applySearchHighlight(stream: ContainerLogStream, force: Bool) {
            let signature = "\(stream.searchQuery)|\(stream.searchIsRegex)|\(stream.searchCaseSensitive)|\(lastRenderedLineId ?? -1)|\(lastDroppedCount)"
            if !force && signature == lastSearchSignature { return }
            lastSearchSignature = signature

            guard let textView, let storage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.removeAttribute(.backgroundColor, range: fullRange)
            matchRanges.removeAll(keepingCapacity: true)

            let query = stream.searchQuery
            if !query.isEmpty {
                let body = storage.string as NSString
                if stream.searchIsRegex {
                    var options: NSRegularExpression.Options = []
                    if !stream.searchCaseSensitive { options.insert(.caseInsensitive) }
                    if let regex = try? NSRegularExpression(pattern: query, options: options) {
                        regex.enumerateMatches(in: body as String, options: [], range: fullRange) { match, _, _ in
                            if let r = match?.range, r.length > 0 { matchRanges.append(r) }
                        }
                    }
                } else {
                    let opts: NSString.CompareOptions = stream.searchCaseSensitive ? [.literal] : [.caseInsensitive, .literal]
                    var searchStart = 0
                    while searchStart < body.length {
                        let range = body.range(of: query, options: opts, range: NSRange(location: searchStart, length: body.length - searchStart))
                        if range.location == NSNotFound { break }
                        matchRanges.append(range)
                        searchStart = range.location + max(range.length, 1)
                    }
                }

                for (idx, range) in matchRanges.enumerated() {
                    let color = (idx == stream.currentMatchIndex) ? NSColor.systemYellow.withAlphaComponent(0.7) : NSColor.systemYellow.withAlphaComponent(0.35)
                    storage.addAttribute(.backgroundColor, value: color, range: range)
                }
            }
            storage.endEditing()

            stream.matchCount = matchRanges.count
            if stream.currentMatchIndex >= matchRanges.count {
                stream.currentMatchIndex = max(0, matchRanges.count - 1)
            }
        }

        private func scrollToCurrentMatch(stream: ContainerLogStream) {
            guard let textView, stream.currentMatchIndex >= 0, stream.currentMatchIndex < matchRanges.count else { return }
            let range = matchRanges[stream.currentMatchIndex]
            textView.scrollRangeToVisible(range)
            textView.setSelectedRange(range)
            // Re-apply current-match color (mark previous one back to normal)
            applySearchHighlight(stream: stream, force: true)
        }

        // MARK: - Follow / scroll

        private func scrollToBottomIfFollowing(stream: ContainerLogStream) {
            guard let textView, let scrollView else { return }
            if stream.followLogs && !stream.userScrolled {
                DispatchQueue.main.async {
                    textView.scrollToEndOfDocument(nil)
                }
                return
            }
            _ = scrollView
        }

        @objc func boundsDidChange(_ notification: Notification) {
            guard let scrollView else { return }
            let visibleMaxY = scrollView.documentVisibleRect.maxY
            let contentHeight = scrollView.documentView?.bounds.height ?? scrollView.contentSize.height
            let atBottom = (contentHeight - visibleMaxY) <= 20
            let stream = parentStream
            DispatchQueue.main.async { [stream] in
                if atBottom {
                    stream.userScrolled = false
                } else if stream.followLogs {
                    stream.userScrolled = true
                }
            }
        }
    }
}

// MARK: - LogTextView (custom NSTextView for context menu)

final class LogTextView: NSTextView {
    weak var coordinator: SelectableLogText.Coordinator?

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        if menu.items.isEmpty == false {
            menu.addItem(.separator())
        }

        let copyAll = NSMenuItem(title: NSLocalizedString("logsCopyAll", comment: ""), action: #selector(copyAllAction(_:)), keyEquivalent: "")
        copyAll.target = self
        menu.addItem(copyAll)

        let copyWithTs = NSMenuItem(title: NSLocalizedString("logsCopyWithTimestamps", comment: ""), action: #selector(copyAllWithTimestampsAction(_:)), keyEquivalent: "")
        copyWithTs.target = self
        menu.addItem(copyWithTs)

        return menu
    }

    @objc func copyAllAction(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(self.string, forType: .string)
    }

    @objc func copyAllWithTimestampsAction(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(self.string, forType: .string)
    }
}
