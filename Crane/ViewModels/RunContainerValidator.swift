//
//  RunContainerValidator.swift
//  Crane
//
//  Pure validation logic extracted from RunContainerViewModel. No store
//  dependencies; cross-cuts come in as closures so this struct is unit-testable
//  without spinning up a CraneStores.
//

import ContainerResource
import Foundation

struct RunContainerValidator {
    let selectedImageID: String?
    let name: String
    let useImageDefaultCommand: Bool
    let imageHasDefaultCommand: Bool
    let executable: String
    let environment: String
    let ports: [PortEntry]
    let mounts: [MountEntry]
    let sockets: [SocketEntry]
    let nameInUse: (String) -> Bool

    var imageValidationMessage: String? {
        selectedImageID == nil ? String(localized: "Select an image.") : nil
    }

    var nameValidationMessage: String? {
        let trimmedName = name.trimmed
        guard !trimmedName.isEmpty else {
            return String(localized: "Enter a container name.")
        }
        if nameInUse(trimmedName) {
            return String(localized: "A container with this name already exists.")
        }
        return nil
    }

    var commandValidationMessage: String? {
        guard selectedImageID != nil else { return nil }

        if useImageDefaultCommand {
            return imageHasDefaultCommand
                ? nil
                : String(localized: "This image doesn’t provide a default command. Enter an executable.")
        }

        return executable.trimmed.isEmpty ? String(localized: "Enter an executable.") : nil
    }

    var environmentValidationMessage: String? {
        let invalidLine = parsedEnvironmentLines.first(where: { !$0.contains("=") })
        guard invalidLine != nil else { return nil }
        return String(localized: "Environment values must use KEY=value format.")
    }

    var portValidationMessage: String? {
        var seenMappings = Set<String>()

        for entry in ports where !entry.isBlank {
            guard !entry.hostPort.trimmed.isEmpty, !entry.containerPort.trimmed.isEmpty else {
                return String(localized: "Port mappings need both a host and container port.")
            }
            guard let hostPort = UInt16(entry.hostPort.trimmed), hostPort > 0,
                  let containerPort = UInt16(entry.containerPort.trimmed), containerPort > 0 else {
                return String(localized: "Ports must be numbers between 1 and 65535.")
            }

            let key = "\(hostPort)-\(entry.proto.rawValue)"
            if !seenMappings.insert(key).inserted {
                return String(localized: "Each host port can only be published once per protocol.")
            }
            _ = containerPort
        }

        return nil
    }

    var mountValidationMessage: String? {
        for entry in mounts where !entry.isBlank {
            guard !entry.destination.trimmed.isEmpty else {
                return String(localized: "Every mount needs a destination path in the container.")
            }

            switch entry.type {
            case .bind, .volume:
                guard !entry.source.trimmed.isEmpty else {
                    return String(localized: "Folder and volume mounts need a source.")
                }
            case .tmpfs:
                break
            }
        }

        return nil
    }

    var socketValidationMessage: String? {
        for entry in sockets where !entry.isBlank {
            guard !entry.hostPath.trimmed.isEmpty, !entry.containerPath.trimmed.isEmpty else {
                return String(localized: "Socket forwards need both host and container paths.")
            }
        }
        return nil
    }

    var validationMessage: String? {
        imageValidationMessage
            ?? nameValidationMessage
            ?? commandValidationMessage
            ?? environmentValidationMessage
            ?? portValidationMessage
            ?? mountValidationMessage
            ?? socketValidationMessage
    }

    var canRun: Bool {
        selectedImageID != nil && validationMessage == nil
    }

    var parsedEnvironmentLines: [String] {
        environment
            .split(separator: "\n")
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
    }
}
