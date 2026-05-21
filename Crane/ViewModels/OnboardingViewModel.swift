//
//  OnboardingViewModel.swift
//  Crane
//

import ContainerAPIClient
import Foundation
import Observation
import Virtualization

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case cli
    case apiserver
    case rosetta
    case notifications
    case done

    var id: Int { rawValue }

    func next() -> OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    func previous() -> OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }
}

enum OnboardingStepStatus: Equatable {
    case idle
    case running
    case ok(String? = nil)
    case failed(String)
    case skipped
    case notSupported(String)

    var isTerminal: Bool {
        switch self {
        case .ok, .failed, .skipped, .notSupported: return true
        default: return false
        }
    }
}

@MainActor
@Observable
final class OnboardingViewModel {
    var step: OnboardingStep = .welcome

    var cliStatus: OnboardingStepStatus = .idle
    var apiserverStatus: OnboardingStepStatus = .idle
    var rosettaStatus: OnboardingStepStatus = .idle
    var notificationsStatus: OnboardingStepStatus = .idle

    /// Mirror of `AppSettings.launchContainerizationService` so the toggle in the
    /// apiserver step is reactive without going through `@AppStorage` (this VM is `@Observable`).
    var autoLaunchService: Bool {
        didSet {
            AppSettings.defaults.set(autoLaunchService, forKey: "launchContainerizationFramework")
        }
    }

    var resolvedCLIPath: String?

    init() {
        self.autoLaunchService = AppSettings.launchContainerizationService
    }

    func advance() {
        if let next = step.next() { step = next }
    }

    func back() {
        if let prev = step.previous() { step = prev }
    }

    func finish(complete: () -> Void) {
        AppSettings.hasCompletedOnboarding = true
        complete()
    }

    // MARK: - CLI

    func checkCLI() {
        cliStatus = .running
        let url = containerCLIExecutableURL()
        resolvedCLIPath = url?.path
        if let path = url?.path {
            cliStatus = .ok(path)
        } else {
            cliStatus = .failed(String(localized: "onboardingCLIMissing"))
        }
    }

    // MARK: - apiserver

    func startApiserver() async {
        apiserverStatus = .running
        let result = await startContainerService()
        if !result.success {
            apiserverStatus = .failed(result.stderr ?? String(localized: "onboardingApiserverStartFailed"))
            return
        }

        let label = "com.apple.container.apiserver"
        let domain = "gui/\(getuid())"
        var registered = false
        for _ in 0..<30 {
            if isServiceLoaded(label: label, domain: domain) {
                registered = true
                break
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        if !registered {
            apiserverStatus = .failed(String(localized: "onboardingApiserverNotRegistered"))
            return
        }

        for _ in 0..<3 {
            do {
                _ = try await ClientHealthCheck.ping(timeout: .seconds(2))
                apiserverStatus = .ok()
                return
            } catch {
                continue
            }
        }
        apiserverStatus = .failed(String(localized: "onboardingApiserverHealthFailed"))
    }

    func skipApiserver() {
        apiserverStatus = .skipped
    }

    // MARK: - rosetta

    func checkRosetta() {
        switch VZLinuxRosettaDirectoryShare.availability {
        case .installed:
            rosettaStatus = .ok()
        case .notSupported:
            rosettaStatus = .notSupported(String(localized: "rosettaLinuxVMNotSupported"))
        case .notInstalled:
            rosettaStatus = .idle
        @unknown default:
            rosettaStatus = .idle
        }
    }

    func installRosetta() async {
        rosettaStatus = .running
        do {
            try await LinuxVMRosettaInstaller.installIfNeeded()
            rosettaStatus = .ok()
        } catch {
            rosettaStatus = .failed(error.localizedDescription)
        }
    }

    func skipRosetta() {
        rosettaStatus = .skipped
    }

    // MARK: - notifications

    func requestNotifications() async {
        notificationsStatus = .running
        let granted = await NotificationsManager.requestAuthorization()
        notificationsStatus = granted
            ? .ok()
            : .skipped
    }

    func skipNotifications() {
        notificationsStatus = .skipped
    }
}
