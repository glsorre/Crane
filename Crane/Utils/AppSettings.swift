import Foundation

enum AppSettings {
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// Backing UserDefaults. Override in tests to use an isolated suite.
    static var defaults: UserDefaults = .standard

    static var autoRefresh: Bool {
        if isRunningTests { return false }
        return defaults.object(forKey: "autoRefresh") == nil
            ? true
            : defaults.bool(forKey: "autoRefresh")
    }

    static var refreshInterval: Int {
        max(defaults.integer(forKey: "refreshInterval"), 1)
    }

    static var maxPollingInterval: Int {
        let val = defaults.integer(forKey: "maxPollingInterval")
        return val > 0 ? val : 30
    }

    static var launchContainerizationService: Bool {
        defaults.object(forKey: "launchContainerizationFramework") == nil
            ? true
            : defaults.bool(forKey: "launchContainerizationFramework")
    }

    static var persistentContainerIDs: Set<String> {
        get {
            Set(defaults.stringArray(forKey: "persistentContainerIDs") ?? [])
        }
        set {
            defaults.set(Array(newValue), forKey: "persistentContainerIDs")
        }
    }

    static func addPersistentContainerID(_ id: String) {
        var ids = persistentContainerIDs
        ids.insert(id)
        persistentContainerIDs = ids
    }

    static func removePersistentContainerID(_ id: String) {
        var ids = persistentContainerIDs
        ids.remove(id)
        persistentContainerIDs = ids
    }
}
