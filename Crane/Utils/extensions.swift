//
//  extensions.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 10/11/25.
//

import ContainerAPIClient
import ContainerResource
import ContainerXPC
import Containerization
import ContainerizationOS
import Foundation
import SwiftUI
import os.log

extension Logger {
    static let crane = Logger(subsystem: "me.rightright.RightCrane", category: "General")
}

extension ContainerSnapshot: @retroactive Identifiable {}

func mountDisplaySource(_ mount: Filesystem) -> String {
    mount.isVolume ? String(mount.source.dropLast(11)) : mount.source
}

extension RuntimeStatus {
    func getDescription() -> String {
        switch self {
        case .running:
            return "Running"
        case .stopped:
            return "Stopped"
        case .stopping:
            return "Stopping"
        default:
            return "Unknown"
        }
    }
    
    func getColor() -> Color {
        switch self {
        case .running:
            return .green
        case .stopped:
            return .red
        case .stopping:
            return .yellow
        default:
            return .gray
        }
    }
    
    func getIcon() -> String {
        switch self {
        case .running:
            return "play.circle.fill"
        case .stopped:
            return "stop.circle.fill"
        case .stopping:
            return "stop.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    func getAction() -> String? {
        switch self {
        case .running:
            return "Stop"
        case .stopped:
            return "Start"
        default:
            return nil
        }
    }
}


