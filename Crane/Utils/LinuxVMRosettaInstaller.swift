//
//  LinuxVMRosettaInstaller.swift
//  Crane
//

import Foundation
import Virtualization

/// Linux VM Rosetta (x86_64 Linux binaries in Apple Container VMs) — separate from Mac “Rosetta 2” for Intel apps.
enum LinuxVMRosettaInstaller {
    @available(macOS 13.0, *)
    static func installIfNeeded() async throws {
        switch VZLinuxRosettaDirectoryShare.availability {
        case .installed:
            return
        case .notSupported:
            throw RosettaInstallError.notSupportedByHardware
        case .notInstalled:
            break
        @unknown default:
            break
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            VZLinuxRosettaDirectoryShare.installRosetta { error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume()
                }
            }
        }
    }
}

enum RosettaInstallError: LocalizedError {
    case notSupportedByHardware
    case requiresMacOS13

    var errorDescription: String? {
        switch self {
        case .notSupportedByHardware:
            return String(localized: "rosettaLinuxVMNotSupported")
        case .requiresMacOS13:
            return String(localized: "rosettaLinuxVMRequiresOS")
        }
    }
}
