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
    @AppStorage("notifyOnConnectionLost") private var notifyOnConnectionLost: Bool = true

    var body: some View {
        Form {
            Section("general") {
                LaunchAtLogin.Toggle(String(localized: "launchAtLogin"))
                Toggle("launchContainerizationService", isOn: $launchContainerizationFramework)
            }
            Section("autoRefresh") {
                Toggle("autoRefresh", isOn: $autoRefresh)

                LabeledContent("listInterval") {
                    NumericField(value: $refreshInterval).frame(width: 80)
                }
                LabeledContent("maxIdleInterval") {
                    NumericField(value: $maxPollingInterval).frame(width: 80)
                }
            }
            Section("notifications") {
                Toggle("notificationsEnabled", isOn: $notificationsEnabled)
                Toggle("notifyOnContainerExit", isOn: $notifyOnContainerExit)
                    .disabled(!notificationsEnabled)
                Toggle("notifyOnImageFetchDone", isOn: $notifyOnImageFetchDone)
                    .disabled(!notificationsEnabled)
                Toggle("notifyOnImageFetchFailed", isOn: $notifyOnImageFetchFailed)
                    .disabled(!notificationsEnabled)
                Toggle("notifyOnBuildDone", isOn: $notifyOnBuildDone)
                    .disabled(!notificationsEnabled)
                Toggle("notifyOnConnectionLost", isOn: $notifyOnConnectionLost)
                    .disabled(!notificationsEnabled)
            }
            Section("setup") {
                Button("runSetupAgain") {
                    AppSettings.hasCompletedOnboarding = false
                    NotificationCenter.default.post(name: .craneRunOnboardingAgain, object: nil)
                }
            }
        }
        .groupedDialogFormLayout(compensateGroupedBodyInset: false)
        .frame(minWidth: 420, minHeight: 480)
        .padding(Spacing.sm)
    }
}

#Preview {
    CraneSettingsView()
}
