//
//  extensions.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 10/11/25.
//

import Foundation
import ContainerClient
import ContainerNetworkService
import ContainerizationOS
import Containerization
import SwiftUI

extension ClientContainer: @retroactive Identifiable {}

extension Attachment: @retroactive Hashable {
    public static func == (lhs: Attachment, rhs: Attachment) -> Bool {
        return lhs.network == rhs.network &&
               lhs.hostname == rhs.hostname &&
               lhs.address == rhs.address &&
               lhs.gateway == rhs.gateway
    }
    
    public static func ~= (lhs: AttachmentConfiguration, rhs: Attachment) -> Bool {
        return lhs.network == rhs.network
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(network)
        hasher.combine(hostname)
        hasher.combine(address)
        hasher.combine(gateway)
    }
}

extension Attachment: @retroactive Identifiable {
    public var id: String { network }
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
