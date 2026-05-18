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

enum CraneErrorSeverity {
    case info
    case warning
    case error
    case fatal
}

enum PolledResource: String, Sendable {
    case containers
    case images
    case networks
    case volumes
}

struct LaunchDiagnostic: Equatable {
    var serviceRegistered: Bool = false
    var launchctlPrintOutput: String?
    var startAttemptStderr: String?
    var pingError: String?
    var plistFound: Bool = false
    var cliPath: String?

    static let empty = LaunchDiagnostic()
}

enum CraneError: LocalizedError {
    case notRegistered(diagnostic: LaunchDiagnostic)
    case notRunning(diagnostic: LaunchDiagnostic)
    case containerNotFound
    case imageFetchingFailed
    case containerStartFailed(underlying: Error)
    case containerStopFailed(underlying: Error)
    case containerRestartFailed(underlying: Error)
    case containerShellFailed(underlying: Error)
    case containerRemoveFailed(underlying: Error)
    case imageRemoveFailed(underlying: Error)
    case imageTagFailed(underlying: Error)
    case imageRenameFailed(underlying: Error)
    case imageFetchFailed(underlying: Error)
    case logStreamFailed(underlying: Error)
    case imageBuildFailed(underlying: Error)
    case networkRemoveFailed(underlying: Error)
    case volumeRemoveFailed(underlying: Error)
    case pollingFailed(resource: PolledResource, underlying: Error)
    case connectionLost(consecutiveFailures: Int)

    var severity: CraneErrorSeverity {
        switch self {
        case .notRegistered, .notRunning:
            return .fatal
        case .connectionLost, .pollingFailed:
            return .warning
        default:
            return .error
        }
    }

    var fatal: Bool { severity == .fatal }

    var diagnostic: LaunchDiagnostic? {
        switch self {
        case .notRegistered(let diagnostic), .notRunning(let diagnostic):
            return diagnostic
        default:
            return nil
        }
    }

    var underlyingError: Error? {
        switch self {
        case .containerStartFailed(let err), .containerStopFailed(let err), .containerRestartFailed(let err),
            .containerShellFailed(let err), .containerRemoveFailed(let err),
            .imageRemoveFailed(let err), .imageTagFailed(let err), .imageRenameFailed(let err),
            .imageFetchFailed(let err), .logStreamFailed(let err), .imageBuildFailed(let err),
            .networkRemoveFailed(let err), .volumeRemoveFailed(let err),
            .pollingFailed(_, let err):
            return err
        default:
            return nil
        }
    }

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
        case .containerStartFailed(let err):
            return String(localized: "containerStartFailedDetail \(err.localizedDescription)")
        case .containerStopFailed(let err):
            return String(localized: "containerStopFailedDetail \(err.localizedDescription)")
        case .containerRestartFailed(let err):
            return String(localized: "containerRestartFailedDetail \(err.localizedDescription)")
        case .containerShellFailed(let err):
            return String(localized: "containerShellFailedDetail \(err.localizedDescription)")
        case .containerRemoveFailed(let err):
            return String(localized: "containerRemoveFailedDetail \(err.localizedDescription)")
        case .imageRemoveFailed(let err):
            return String(localized: "imageRemoveFailedDetail \(err.localizedDescription)")
        case .imageTagFailed(let err):
            return String(localized: "imageTagFailedDetail \(err.localizedDescription)")
        case .imageRenameFailed(let err):
            return String(localized: "imageRenameFailedDetail \(err.localizedDescription)")
        case .imageFetchFailed(let err):
            return String(localized: "imageFetchFailedDetail \(err.localizedDescription)")
        case .logStreamFailed(let err):
            return String(localized: "logStreamFailedDetail \(err.localizedDescription)")
        case .imageBuildFailed(let err):
            return String(localized: "imageBuildFailedDetail \(err.localizedDescription)")
        case .networkRemoveFailed(let err):
            return String(localized: "networkRemoveFailedDetail \(err.localizedDescription)")
        case .volumeRemoveFailed(let err):
            return String(localized: "volumeRemoveFailedDetail \(err.localizedDescription)")
        case .pollingFailed(let resource, let err):
            return String(localized: "pollingFailedDetail \(resource.rawValue) \(err.localizedDescription)")
        case .connectionLost(let count):
            return String(localized: "connectionLostDetail \(count)")
        }
    }

    /// Returns NSError domain/code when underlying is an NSError, otherwise nil.
    /// Useful for surfacing copy-paste-friendly debug detail in diagnostic UI.
    var debugDetail: String? {
        guard let underlying = underlyingError else { return nil }
        let nsErr = underlying as NSError
        return "\(nsErr.domain) #\(nsErr.code)"
    }
}

enum CraneTab: Hashable {
    case containers
    case images
    case networks
    case volumes

    var polledResource: PolledResource {
        switch self {
        case .containers: return .containers
        case .images: return .images
        case .networks: return .networks
        case .volumes: return .volumes
        }
    }
}

@Observable
class AppViewModel {
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
