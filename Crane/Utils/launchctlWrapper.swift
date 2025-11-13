//
//  launchctlWrapper.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 13/11/25.
//

import Foundation

func isServiceLoaded(label: String, domain: String) -> Bool {
    let process = Process()
    let pipe = Pipe()
    
    // Use "/bin/launchctl" as the executable path
    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    
    // Construct the arguments, e.g., ["print", "system/com.my.service"]
    // Or ["list"] if you prefer the legacy method
    process.arguments = ["print", "\(domain)/\(label)"]
    
    process.standardOutput = pipe
    process.standardError = pipe // Capture errors too
    
    do {
        try process.run()
        process.waitUntilExit()
        
        // Read the output
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // If the command fails, terminationStatus will be non-zero
        // and the output will contain "Could not find service"
        if process.terminationStatus == 0 && !output.isEmpty {
            // Success: The service was found and info was printed
            return true
        } else {
            // Failure: The service was not found
            // You can optionally check if output.contains("Could not find service")
            return false
        }
    } catch {
        return false
    }
}
