//
//  isServiceLoaded.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 13/11/25.
//

import Foundation

func isServiceLoaded(label: String, domain: String) -> Bool {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    process.arguments = ["print", "\(domain)/\(label)"]
    process.standardOutput = pipe
    process.standardError = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        if process.terminationStatus == 0 && !output.isEmpty {
            return true
        } else {
            return false
        }
    } catch {
        return false
    }
}
