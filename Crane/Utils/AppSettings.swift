import Foundation

enum AppSettings {
    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    static var autoRefresh: Bool {
        if isRunningTests { return false }
        return UserDefaults.standard.object(forKey: "autoRefresh") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "autoRefresh")
    }

    static var refreshInterval: Int {
        max(UserDefaults.standard.integer(forKey: "refreshInterval"), 1)
    }

    static var maxPollingInterval: Int {
        let val = UserDefaults.standard.integer(forKey: "maxPollingInterval")
        return val > 0 ? val : 30
    }

    static var launchContainerizationService: Bool {
        UserDefaults.standard.object(forKey: "launchContainerizationFramework") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "launchContainerizationFramework")
    }

    static var persistentContainerIDs: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: "persistentContainerIDs") ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "persistentContainerIDs")
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
