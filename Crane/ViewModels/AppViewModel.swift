//
//  ViewModel.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 10/11/25.
//

import ContainerClient
import ContainerNetworkService
import ContainerizationOCI
import Foundation
import Combine
import Observation
import SwiftUI

enum CraneError: LocalizedError {
    case notRegistered
    case notRunning
    case containerNotFound
    
    var errorDescription: String {
        switch self {
        case .notRegistered:
            return String(localized: "notRegistered")
        case .notRunning:
            return String(localized: "notRegistered")
        case .containerNotFound:
            return String(localized: "containerNotFound")
        }
    }
    
    var fatal: Bool {
        switch self {
        case .notRegistered, .notRunning:
            return true
        case .containerNotFound:
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
        if removeStack {
            self.path.removeLast(self.path.count - 1)
        }
        self.path.append(route)
    }
}
