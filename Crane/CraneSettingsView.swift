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
            Section("general") {
                LaunchAtLogin.Toggle("launchAtLogin")
            }
            Section("autoRefresh") {
                Toggle("autoRefresh", isOn: $autoRefresh)
                
                GeometryReader { geometry in
                    HStack {
                        Text("listInterval")
                            .frame(width: geometry.size.width * 0.8, alignment: .leading)
                        NumericField(value: $refreshInterval)
                            .frame(alignment: .trailing)
                    }
                    .frame(alignment: .center)
                }
                
                GeometryReader { geometry in
                    HStack {
                        Text("logsInterval")
                            .frame(width: geometry.size.width * 0.8, alignment: .leading)
                        NumericField(value: $logInterval)
                            .frame(alignment: .trailing)
                    }
                    .frame(alignment: .center)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 400, minHeight: 320)
    }
}

#Preview {
    CraneSettingsView()
}
