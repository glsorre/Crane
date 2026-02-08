import Foundation

enum AppSettings {
    static var refreshInterval: Int {
        max(UserDefaults.standard.integer(forKey: "refreshInterval"), 1)
    }

    static var logsInterval: Int {
        max(UserDefaults.standard.integer(forKey: "logsInterval"), 1)
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
