//
//  CraneSettingsView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 12/11/25.
//

import LaunchAtLogin
import SwiftUI

struct CraneSettingsView: View {
    @AppStorage("launchContainerizationFramework") private var launchContainerizationFramework: Bool = true
    @AppStorage("autoRefresh") private var autoRefresh: Bool = true
    @AppStorage("refreshInterval") private var refreshInterval: Int = 1
    @AppStorage("maxPollingInterval") private var maxPollingInterval: Int = 30

    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("notifyOnContainerExit") private var notifyOnContainerExit: Bool = true
    @AppStorage("notifyOnImageFetchDone") private var notifyOnImageFetchDone: Bool = true
    @AppStorage("notifyOnImageFetchFailed") private var notifyOnImageFetchFailed: Bool = true
    @AppStorage("notifyOnBuildDone") private var notifyOnBuildDone: Bool = true
    @AppStorage("notifyOnRunFailed") private var notifyOnRunFailed: Bool = true
    @AppStorage("notifyOnConnectionLost") private var notifyOnConnectionLost: Bool = true

    @AppStorage("logTheme.dark") private var logThemeDark: String = LogTheme.monokai.rawValue
    @AppStorage("logTheme.light") private var logThemeLight: String = LogTheme.default.rawValue

    @AppStorage("terminalApp") private var terminalApp: String = TerminalApp.systemDefault.rawValue
    @AppStorage("terminalCustomCommand") private var terminalCustomCommand: String = "open -a Terminal {script}"

    @EnvironmentObject private var updaterModel: UpdaterModel

    private var selectedLogThemeDark: LogTheme {
        LogTheme(rawValue: logThemeDark) ?? .monokai
    }

    private var selectedLogThemeLight: LogTheme {
        LogTheme(rawValue: logThemeLight) ?? .default
    }

    private var selectedTerminalApp: TerminalApp {
        TerminalApp(rawValue: terminalApp) ?? .systemDefault
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                generalSection
                terminalSection
                autoRefreshSection
                logThemeSection
                notificationsSection
                updatesSection
                setupSection
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var generalSection: some View {
        SettingsGroup(title: "general") {
            SettingsRow {
                LaunchAtLogin.Toggle(String(localized: "launchAtLogin"))
            }
            SettingsRow {
                Toggle("launchContainerizationService", isOn: $launchContainerizationFramework)
            }
        }
    }

    private var terminalSection: some View {
        SettingsGroup(title: "terminal") {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: Spacing.sm)],
                spacing: Spacing.sm
            ) {
                ForEach(TerminalApp.allCases) { app in
                    TerminalAppCard(
                        app: app,
                        isSelected: selectedTerminalApp == app,
                        onSelect: { terminalApp = app.rawValue }
                    )
                }
            }
            if selectedTerminalApp == .custom {
                SettingsRow {
                    TextField("terminalCustomCommand", text: $terminalCustomCommand)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
    }

    private var autoRefreshSection: some View {
        SettingsGroup(title: "autoRefresh") {
            SettingsRow {
                Toggle("autoRefresh", isOn: $autoRefresh)
            }
            SettingsRow {
                LabeledContent("listInterval") {
                    NumericField(value: $refreshInterval).frame(width: 80)
                }
            }
            SettingsRow {
                LabeledContent("maxIdleInterval") {
                    NumericField(value: $maxPollingInterval).frame(width: 80)
                }
            }
        }
    }

    private var logThemeSection: some View {
        SettingsGroup(title: "logTheme") {
            logThemeRail(titleKey: "logThemeDarkHeader", selected: selectedLogThemeDark, isDark: true) { theme in
                logThemeDark = theme.rawValue
            }
            logThemeRail(titleKey: "logThemeLightHeader", selected: selectedLogThemeLight, isDark: false) { theme in
                logThemeLight = theme.rawValue
            }
            .padding(.top, Spacing.md)
        }
    }

    @ViewBuilder
    private func logThemeRail(
        titleKey: LocalizedStringKey,
        selected: LogTheme,
        isDark: Bool,
        onSelect: @escaping (LogTheme) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.subsection) {
            Text(titleKey)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.vertical, Spacing.xs)
            // Flow the cards into a wrapping grid. The previous design used
            // a nested `NSScrollView` (so vertical wheel deltas would pass
            // through to the outer `ScrollView`), but reliably sizing a
            // SwiftUI document view for `NSScrollView` proved impossible
            // — the cards were always cut off and the scroll bar never
            // appeared. A wrapping layout sidesteps the entire problem:
            // no horizontal scroll view means no sizing gymnastics and no
            // gesture conflict with the outer vertical scroller. Every
            // card is visible and selectable at once, and the settings
            // page scrolls vertically as expected.
            WrappingHStack(
                horizontalSpacing: Spacing.md,
                verticalSpacing: Spacing.lg
            ) {
                ForEach(LogTheme.allCases) { theme in
                    LogThemePreviewCard(
                        theme: theme,
                        palette: isDark ? theme.darkPalette() : theme.lightPalette(),
                        isSelected: selected == theme,
                        onSelect: { onSelect(theme) }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var notificationsSection: some View {
        SettingsGroup(title: "notifications") {
            SettingsRow {
                Toggle("notificationsEnabled", isOn: $notificationsEnabled)
            }
            SettingsRow {
                Toggle("notifyOnContainerExit", isOn: $notifyOnContainerExit)
                    .disabled(!notificationsEnabled)
            }
            SettingsRow {
                Toggle("notifyOnImageFetchDone", isOn: $notifyOnImageFetchDone)
                    .disabled(!notificationsEnabled)
            }
            SettingsRow {
                Toggle("notifyOnImageFetchFailed", isOn: $notifyOnImageFetchFailed)
                    .disabled(!notificationsEnabled)
            }
            SettingsRow {
                Toggle("notifyOnBuildDone", isOn: $notifyOnBuildDone)
                    .disabled(!notificationsEnabled)
            }
            SettingsRow {
                Toggle("notifyOnRunFailed", isOn: $notifyOnRunFailed)
                    .disabled(!notificationsEnabled)
            }
            SettingsRow {
                Toggle("notifyOnConnectionLost", isOn: $notifyOnConnectionLost)
                    .disabled(!notificationsEnabled)
            }
        }
    }

    private var updatesSection: some View {
        SettingsGroup(title: "updates") {
            SettingsRow {
                Toggle("automaticallyCheckForUpdates", isOn: $updaterModel.automaticallyChecksForUpdates)
            }
            SettingsRow {
                Toggle("automaticallyDownloadUpdates", isOn: $updaterModel.automaticallyDownloadsUpdates)
                    .disabled(!updaterModel.automaticallyChecksForUpdates)
            }
            SettingsRow {
                Button("checkForUpdatesNow") {
                    updaterModel.checkForUpdates()
                }
                .disabled(!updaterModel.canCheckForUpdates)
            }
        }
    }

    private var setupSection: some View {
        SettingsGroup(title: "setup") {
            SettingsRow {
                Button("runSetupAgain") {
                    AppSettings.hasCompletedOnboarding = false
                    NotificationCenter.default.post(name: .craneRunOnboardingAgain, object: nil)
                }
            }
        }
    }
}

/// Card-style settings group with a header and a list of rows. Visually
/// consistent with the in-app detail views.
private struct SettingsGroup<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.headline)
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
            )
        }
    }
}

/// Single row inside a `SettingsGroup`. Adds a hairline divider between rows
/// so the group reads as a stacked list.
private struct SettingsRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
            Divider()
                .padding(.leading, Spacing.md)
        }
    }
}
