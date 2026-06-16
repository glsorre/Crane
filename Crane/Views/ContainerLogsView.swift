//
//  ContainerLogsView.swift
//  Crane
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContainerLogsView: View {
    @Bindable var viewModel: DetailsViewModel
    @Environment(\.colorScheme) private var colorScheme
    // Register observation so the view re-renders when the theme pickers change.
    // The Coordinator reads the live values from UserDefaults directly; these
    // exist solely to make SwiftUI re-render the logs view on a Picker change.
    @AppStorage("logTheme.dark") private var logThemeDark: String = ContainerLogStream.defaultThemeDark
    @AppStorage("logTheme.light") private var logThemeLight: String = ContainerLogStream.defaultThemeLight
    @State private var showClearConfirm: Bool = false

    private var stream: ContainerLogStream {
        let handleIndex = viewModel.currentHandle
        if let metadata = viewModel.logHandles[handleIndex] {
            return metadata
        }
        let new = ContainerLogStream()
        viewModel.logHandles[handleIndex] = new
        return new
    }

    var body: some View {
        let stream = self.stream

        VStack(spacing: 0) {
            toolbar(stream: stream)
                .padding(.horizontal, Spacing.subsection)
                .padding(.vertical, Spacing.xs)
                .background(.bar)

            Divider()

            ZStack(alignment: .bottomTrailing) {
                SelectableLogText(
                    stream: stream,
                    colorScheme: colorScheme,
                    themeDark: logThemeDark,
                    themeLight: logThemeLight
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if stream.userScrolled && stream.followLogs {
                    jumpToLatestButton(stream: stream)
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: stream.userScrolled)

            Divider()
            statusBar(stream: stream)
                .padding(.horizontal, Spacing.subsection)
                .padding(.vertical, Spacing.xxs)
                .background(.bar)
        }
        .onChange(of: viewModel.currentHandle) { _, newValue in
            viewModel.start(handleIndex: newValue)
        }
        .confirmationDialog(
            String(localized: "logsClearConfirm"),
            isPresented: $showClearConfirm
        ) {
            Button(String(localized: "logsClearConfirmAction"), role: .destructive) {
                stream.clear()
            }
            Button(String(localized: "cancel"), role: .cancel) {}
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private func toolbar(stream: ContainerLogStream) -> some View {
        HStack(spacing: 10) {
            if viewModel.logHandles.count > 1 {
                Picker("", selection: $viewModel.currentHandle) {
                    ForEach(Array(viewModel.logHandles.keys.sorted()), id: \.self) { index in
                        Text(viewModel.getHandleName(handleIndex: index)).tag(index)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 200)
                .fixedSize(horizontal: true, vertical: false)
            }

            searchField(stream: stream)

            Toggle(isOn: Binding(get: { stream.searchCaseSensitive }, set: { stream.searchCaseSensitive = $0 })) {
                Text("Aa").font(.system(size: 11, weight: .medium))
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .help(String(localized: "logsCaseSensitive"))

            Toggle(isOn: Binding(get: { stream.searchIsRegex }, set: { stream.searchIsRegex = $0 })) {
                Text(".*").font(.system(size: 11, weight: .medium).monospaced())
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .help(String(localized: "logsRegex"))

            if !stream.searchQuery.isEmpty {
                matchNavigator(stream: stream)
            }

            Spacer()

            overflowMenu(stream: stream)

            Toggle(
                isOn: Binding(
                    get: { stream.followLogs },
                    set: { newValue in
                        stream.followLogs = newValue
                        if newValue {
                            stream.userScrolled = false
                            stream.forceScroll = true
                        }
                    }
                )
            ) {
                Label(String(localized: "followLogs"), systemImage: "arrow.down.to.line")
                    .labelStyle(.titleAndIcon)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func searchField(stream: ContainerLogStream) -> some View {
        HStack(spacing: 4) {
            SwiftUI.Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
            TextField(
                String(localized: "logsSearchPlaceholder"),
                text: Binding(
                    get: { stream.searchQuery },
                    set: {
                        stream.searchQuery = $0
                        stream.currentMatchIndex = 0
                    })
            )
            .textFieldStyle(.plain)
            .font(.system(.body, design: .monospaced))
            .controlSize(.small)
            if !stream.searchQuery.isEmpty {
                Button(
                    action: {
                        stream.searchQuery = ""
                        stream.currentMatchIndex = 0
                    },
                    label: {
                        SwiftUI.Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                )
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
        .frame(maxWidth: 260)
    }

    @ViewBuilder
    private func matchNavigator(stream: ContainerLogStream) -> some View {
        HStack(spacing: 4) {
            Text(stream.matchCount == 0 ? "0/0" : "\(stream.currentMatchIndex + 1)/\(stream.matchCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Button(
                action: { stepMatch(stream: stream, delta: -1) },
                label: { SwiftUI.Image(systemName: "chevron.up") }
            )
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(stream.matchCount == 0)

            Button(
                action: { stepMatch(stream: stream, delta: +1) },
                label: { SwiftUI.Image(systemName: "chevron.down") }
            )
            .buttonStyle(.borderless)
            .controlSize(.small)
            .disabled(stream.matchCount == 0)
        }
    }

    private func stepMatch(stream: ContainerLogStream, delta: Int) {
        guard stream.matchCount > 0 else { return }
        let next = (stream.currentMatchIndex + delta + stream.matchCount) % stream.matchCount
        stream.currentMatchIndex = next
    }

    @ViewBuilder
    private func overflowMenu(stream: ContainerLogStream) -> some View {
        Menu {
            Section(String(localized: "logsLevelFilter")) {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Toggle(
                        LogLineFormatter.displayName(for: level),
                        isOn: Binding(
                            get: { stream.levelFilter.isEmpty || stream.levelFilter.contains(level) },
                            set: { isOn in
                                if stream.levelFilter.isEmpty {
                                    stream.levelFilter = Set(LogLevel.allCases)
                                }
                                if isOn {
                                    stream.levelFilter.insert(level)
                                } else {
                                    stream.levelFilter.remove(level)
                                }
                                if stream.levelFilter == Set(LogLevel.allCases) {
                                    stream.levelFilter = []
                                }
                            }
                        ))
                }
            }
            Section {
                Toggle(
                    String(localized: "logsShowTimestamps"),
                    isOn: Binding(get: { stream.showTimestamps }, set: { stream.showTimestamps = $0 }))
                Toggle(
                    String(localized: "logsShowLineNumbers"),
                    isOn: Binding(get: { stream.showLineNumbers }, set: { stream.showLineNumbers = $0 }))
            }
            Section {
                Button {
                    stream.fontSize = max(9, stream.fontSize - 1)
                } label: {
                    Label(String(localized: "logsFontDecrease"), systemImage: "textformat.size.smaller")
                }
                Button {
                    stream.fontSize = min(24, stream.fontSize + 1)
                } label: {
                    Label(String(localized: "logsFontIncrease"), systemImage: "textformat.size.larger")
                }
            }
            Section {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(stream.logs.map { $0.message }.joined(separator: "\n"), forType: .string)
                } label: {
                    Label(String(localized: "logsCopyAll"), systemImage: "doc.on.doc")
                }
                Button {
                    exportLogs(stream: stream)
                } label: {
                    Label(String(localized: "logsExport"), systemImage: "square.and.arrow.down")
                }
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label(String(localized: "logsClear"), systemImage: "trash")
                }
            }
        } label: {
            SwiftUI.Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: - Status bar

    @ViewBuilder
    private func statusBar(stream: ContainerLogStream) -> some View {
        HStack(spacing: 12) {
            Text(String(format: String(localized: "logsRenderedTotal"), stream.logs.count, stream.logs.count + stream.droppedCount))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            if stream.droppedCount > 0 {
                Text(String(format: String(localized: "logsDroppedLines"), stream.droppedCount))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    // MARK: - Jump to latest

    @ViewBuilder
    private func jumpToLatestButton(stream: ContainerLogStream) -> some View {
        Button {
            stream.userScrolled = false
            stream.forceScroll = true
        } label: {
            Label(String(localized: "logsJumpToLatest"), systemImage: "chevron.down")
                .labelStyle(.titleAndIcon)
                .font(.caption.bold())
                .padding(.horizontal, Spacing.subsection)
                .padding(.vertical, Spacing.xs)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Export

    private func exportLogs(stream: ContainerLogStream) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText, .log]
        panel.nameFieldStringValue = "container-logs.txt"
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let body = stream.logs.map { line -> String in
                var parts: [String] = []
                if stream.showLineNumbers { parts.append(LogLineFormatter.lineNumberPrefix(line.id)) }
                if stream.showTimestamps { parts.append(LogLineFormatter.timestampPrefix(for: line.arrivedAt)) }
                parts.append(line.message)
                return parts.joined(separator: "  ")
            }.joined(separator: "\n")
            try? body.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
