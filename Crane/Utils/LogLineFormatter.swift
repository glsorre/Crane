//
//  LogLineFormatter.swift
//  Crane
//

import AppKit
import Foundation

enum LogLineFormatter {
    // Pattern is a compile-time constant; the throw can never fire at runtime.
    // swiftlint:disable:next force_try
    private static let levelRegex: NSRegularExpression = try! NSRegularExpression(
        pattern: #"^\s*\[?(FATAL|ERROR|ERR|WARNING|WARN|INFO|DEBUG|DBG|TRACE)\]?\b"#,
        options: [.caseInsensitive]
    )

    static func detectLevel(in message: String) -> LogLevel? {
        let range = NSRange(message.startIndex..<message.endIndex, in: message)
        guard
            let match = levelRegex.firstMatch(in: message, options: [], range: range),
            match.numberOfRanges >= 2,
            let tokenRange = Range(match.range(at: 1), in: message)
        else { return nil }

        let token = message[tokenRange].uppercased()
        switch token {
        case "FATAL": return .fatal
        case "ERROR", "ERR": return .error
        case "WARN", "WARNING": return .warn
        case "INFO": return .info
        case "DEBUG", "DBG": return .debug
        case "TRACE": return .trace
        default: return nil
        }
    }

    static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func timestampPrefix(for date: Date) -> String {
        timestampFormatter.string(from: date)
    }

    static func lineNumberPrefix(_ id: Int) -> String {
        String(format: "%06d", id)
    }

    static func color(for level: LogLevel?) -> NSColor {
        switch level {
        case .fatal: return .systemRed
        case .error: return .systemRed
        case .warn: return .systemOrange
        case .info: return .controlTextColor
        case .debug: return .secondaryLabelColor
        case .trace: return .tertiaryLabelColor
        case .none: return .controlTextColor
        }
    }

    static func displayName(for level: LogLevel) -> String {
        switch level {
        case .fatal: return "FATAL"
        case .error: return "ERROR"
        case .warn: return "WARN"
        case .info: return "INFO"
        case .debug: return "DEBUG"
        case .trace: return "TRACE"
        }
    }
}
