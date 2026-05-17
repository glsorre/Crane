//
//  ViewModel.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 10/11/25.
//

import ContainerAPIClient
import ContainerResource
import ContainerizationOCI
import Foundation
import Observation

enum CraneError: LocalizedError {
    case notRegistered
    case notRunning
    case containerNotFound
    case imageFetchingFailed
    case containerStartFailed(String)
    case containerStopFailed(String)
    case containerRestartFailed(String)
    case containerShellFailed(String)
    case containerRemoveFailed(String)
    case imageRemoveFailed(String)
    case imageTagFailed(String)
    case imageRenameFailed(String)
    case imageFetchFailed(String)
    case logStreamFailed(String)
    case imageBuildFailed(String)
    case networkRemoveFailed(String)
    case volumeRemoveFailed(String)

    var errorDescription: String? {
        switch self {
        case .notRegistered:
            return String(localized: "notRegistered")
        case .notRunning:
            return String(localized: "notRunning")
        case .containerNotFound:
            return String(localized: "containerNotFound")
        case .imageFetchingFailed:
            return String(localized: "imageFetchingFailed")
        case .containerStartFailed(let detail):
            return "Failed to start container: \(detail)"
        case .containerStopFailed(let detail):
            return "Failed to stop container: \(detail)"
        case .containerRestartFailed(let detail):
            return String(localized: "containerRestartFailedDetail \(detail)")
        case .containerShellFailed(let detail):
            return String(localized: "containerShellFailedDetail \(detail)")
        case .containerRemoveFailed(let detail):
            return "Failed to remove container: \(detail)"
        case .imageRemoveFailed(let detail):
            return "Failed to remove image: \(detail)"
        case .imageTagFailed(let detail):
            return String(localized: "imageTagFailedDetail \(detail)")
        case .imageRenameFailed(let detail):
            return String(localized: "imageRenameFailedDetail \(detail)")
        case .imageFetchFailed(let detail):
            return "Failed to fetch image: \(detail)"
        case .logStreamFailed(let detail):
            return "Failed to stream logs: \(detail)"
        case .imageBuildFailed(let detail):
            return "Failed to build image: \(detail)"
        case .networkRemoveFailed(let detail):
            return "Failed to remove network: \(detail)"
        case .volumeRemoveFailed(let detail):
            return "Failed to remove volume: \(detail)"
        }
    }

    var fatal: Bool {
        switch self {
        case .notRegistered, .notRunning:
            return true
        default:
            return false
        }
    }
}

enum CraneTab: Hashable {
    case containers
    case images
    case networks
    case volumes
}
    
@Observable
class AppViewModel {
    static let shared = AppViewModel()

    var selectedTab: CraneTab = .containers
    var selectedContainerID: Container.ID?
    var containerDetailNavigationRequest: Int = 0

    var error: CraneError?
    var errorShow: Bool = false

    func showError(_ error: CraneError) {
        self.error = error
        self.errorShow = true
    }

    func openContainerDetail(_ container: Container) {
        selectedTab = .containers
        selectedContainerID = container.id
        containerDetailNavigationRequest &+= 1
    }

    func showContainersList() {
        selectedTab = .containers
        clearContainerSelection()
    }

    func clearContainerSelection() {
        selectedContainerID = nil
    }
}
