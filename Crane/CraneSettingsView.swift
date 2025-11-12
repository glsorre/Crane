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
    @AppStorage("logsInterval") private var logInterval: Int = 3
    @AppStorage("themePreference") private var themePreference: String = "System"

    var body: some View {
        Form {
            Section("General") {
                LaunchAtLogin.Toggle("Launch at login")
                    .help("Automatically start the Crane container management app when you login")
            }
            Section("Automatism") {
                Toggle("Auto-refresh containers", isOn: $autoRefresh)
                    .help("Automatically refresh container list.")
                
                GeometryReader { geometry in
                    HStack {
                        Text("Refresh container list interval (in seconds)")
                            .frame(width: geometry.size.width * 0.8, alignment: .leading)
                        NumericField(value: $refreshInterval)
                            .help("Interval (in seconds) for refreshing the container list.")
                            .frame(alignment: .trailing)
                    }
                    .frame(alignment: .center)
                }
                
                GeometryReader { geometry in
                    HStack {
                        Text("Log feeds update interval (in seconds)")
                            .frame(width: geometry.size.width * 0.8, alignment: .leading)
                        NumericField(value: $logInterval)
                            .help("Interval (in seconds) for refreshing the logs feeds.")
                            .frame(alignment: .trailing)
                    }
                    .frame(alignment: .center)
                }
            }
            
            Section("Appearance") {
                Picker("Theme", selection: $themePreference) {
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                    Text("System").tag("System")
                }
                .pickerStyle(.menu)
                .help("Choose the app's theme appearance.")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 400, minHeight: 440)  // Recommended minimum size for Settings windows
    }
}

#Preview {
    CraneSettingsView()
}
