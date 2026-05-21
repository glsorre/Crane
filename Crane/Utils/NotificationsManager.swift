//
//  NotificationsManager.swift
//  Crane
//

import Foundation
import UserNotifications
import os

#if os(macOS)
import AppKit
#endif

enum CraneNotificationEvent: String {
    case containerExited
    case imageFetchDone
    case imageFetchFailed
    case buildDone
    case buildFailed
    case connectionLost
    case connectionRestored

    /// Long-running operations get notified even when Crane is frontmost,
    /// because the user typically tabs away while they finish.
    var notifyEvenWhenActive: Bool {
        switch self {
        case .imageFetchDone, .imageFetchFailed, .buildDone, .buildFailed: return true
        default: return false
        }
    }

    var perEventEnabled: Bool {
        switch self {
        case .containerExited: return AppSettings.notifyOnContainerExit
        case .imageFetchDone: return AppSettings.notifyOnImageFetchDone
        case .imageFetchFailed: return AppSettings.notifyOnImageFetchFailed
        case .buildDone, .buildFailed: return AppSettings.notifyOnBuildDone
        case .connectionLost, .connectionRestored: return AppSettings.notifyOnConnectionLost
        }
    }
}

enum NotificationsManager {
    /// Requests notification authorization from the user. Idempotent — macOS returns the prior decision after the first prompt.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            Log.launch.error("requestAuthorization failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    static func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { cont in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                cont.resume(returning: settings.authorizationStatus)
            }
        }
    }

    static func post(_ event: CraneNotificationEvent, title: String, body: String) {
        guard AppSettings.notificationsEnabled, event.perEventEnabled else { return }

        Task { @MainActor in
            #if os(macOS)
            if !event.notifyEvenWhenActive, NSApp?.isActive == true {
                return
            }
            #endif

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "\(event.rawValue)-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    Log.launch.error(
                        "post notification \(event.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }
    }
}
