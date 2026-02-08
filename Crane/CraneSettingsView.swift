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
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 280)
        .padding(Spacing.sm)
    }
}

#Preview {
    CraneSettingsView()
}
