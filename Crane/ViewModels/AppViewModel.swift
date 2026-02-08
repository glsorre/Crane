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
import SwiftUI

enum CraneError: LocalizedError {
    case notRegistered
    case notRunning
    case containerNotFound
    case imageFetchingFailed
    case containerStartFailed(String)
    case containerStopFailed(String)
    case containerRemoveFailed(String)
    case imageRemoveFailed(String)
    case imageFetchFailed(String)
    case networkCreateFailed(String)
    case logStreamFailed(String)
    case imageBuildFailed(String)
    case networkRemoveFailed(String)
    case volumeCreateFailed(String)
    case volumeRemoveFailed(String)

    var errorDescription: String {
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
        case .containerRemoveFailed(let detail):
            return "Failed to remove container: \(detail)"
        case .imageRemoveFailed(let detail):
            return "Failed to remove image: \(detail)"
        case .imageFetchFailed(let detail):
            return "Failed to fetch image: \(detail)"
        case .networkCreateFailed(let detail):
            return "Failed to create network: \(detail)"
        case .logStreamFailed(let detail):
            return "Failed to stream logs: \(detail)"
        case .imageBuildFailed(let detail):
            return "Failed to build image: \(detail)"
        case .networkRemoveFailed(let detail):
            return "Failed to remove network: \(detail)"
        case .volumeCreateFailed(let detail):
            return "Failed to create volume: \(detail)"
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

enum CraneRoute: Hashable {
    case detail(container: Container)
    case list
}
    
@Observable
class AppViewModel {
    static let shared = AppViewModel()
    
    var path: NavigationPath = NavigationPath()
    
    var error: CraneError?
    var errorShow: Bool = false
    
    func showError(_ error: CraneError) {
        self.error = error
        self.errorShow = true
    }
    
    func navigateTo(to route: CraneRoute, removeStack: Bool = false) {
        self.path.append(route)
        if removeStack {
            self.path.removeLast(self.path.count - 1)
        }
    }
}
