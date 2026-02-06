import Foundation

enum AppSettings {
    static var refreshInterval: Int {
        max(UserDefaults.standard.integer(forKey: "refreshInterval"), 1)
    }

    static var logsInterval: Int {
        max(UserDefaults.standard.integer(forKey: "logsInterval"), 1)
    }
}
