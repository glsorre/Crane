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
    // Manual implementation required for @retroactive conformance outside the declaring file.
    // Adjust based on Attachment's actual properties (e.g., assuming an 'id' field exists).
    public static func == (lhs: Attachment, rhs: Attachment) -> Bool {
        return lhs.network == rhs.network  // Replace with actual equality logic if Attachment has different fields.
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(network)  // Replace with actual properties that uniquely identify Attachment.
    }
}

extension RandomAccessCollection where Element: Identifiable, Element.ID == String {
    func fromIndex(_ id: String) -> Element? {
        first { $0.id == id }
    }
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
