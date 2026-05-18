//
//  FetchProgress.swift
//  Crane
//

import Foundation
import Observation
import TerminalProgress

@Observable
final class FetchProgress {
    var fetchDescription: String = ""
    var subDescription: String = ""
    var itemsName: String = "items"
    var items: Int = 0
    var totalItems: Int = 0
    var tasks: Int = 0
    var totalTasks: Int = 0
    var size: Int64 = 0
    var totalSize: Int64 = 0
    var custom: String = ""

    var fraction: Double? {
        if totalSize > 0 {
            return min(1, Double(size) / Double(totalSize))
        }
        if totalItems > 0 {
            return min(1, Double(items) / Double(totalItems))
        }
        return nil
    }

    var bytesDescription: String? {
        guard totalSize > 0 || size > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        let current = formatter.string(fromByteCount: size)
        if totalSize > 0 {
            let total = formatter.string(fromByteCount: totalSize)
            return "\(current) / \(total)"
        }
        return current
    }

    var itemsDescription: String? {
        guard totalItems > 0 else { return nil }
        return "\(items)/\(totalItems) \(itemsName)"
    }

    // swiftlint:disable:next cyclomatic_complexity
    func apply(_ events: [ProgressUpdateEvent]) {
        for event in events {
            switch event {
            case .setDescription(let value): fetchDescription = value
            case .setSubDescription(let value): subDescription = value
            case .setItemsName(let value): itemsName = value
            case .addTasks(let value): tasks += value
            case .setTasks(let value): tasks = value
            case .addTotalTasks(let value): totalTasks += value
            case .setTotalTasks(let value): totalTasks = value
            case .addItems(let value): items += value
            case .setItems(let value): items = value
            case .addTotalItems(let value): totalItems += value
            case .setTotalItems(let value): totalItems = value
            case .addSize(let value): size += value
            case .setSize(let value): size = value
            case .addTotalSize(let value): totalSize += value
            case .setTotalSize(let value): totalSize = value
            case .custom(let value): custom = value
            }
        }
    }
}
