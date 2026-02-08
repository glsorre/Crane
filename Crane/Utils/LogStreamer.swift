import Foundation

func streamLogFile(fileHandle: FileHandle) -> AsyncStream<String> {
    AsyncStream { continuation in
        var buffer = Data()
        fileHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.seekToEndOfFile()
                return
            }
            buffer.append(data)
            while let range = buffer.range(of: Data("\n".utf8)) {
                if let line = String(data: buffer[buffer.startIndex..<range.lowerBound], encoding: .utf8) {
                    continuation.yield(line)
                }
                buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            }
        }
        continuation.onTermination = { @Sendable _ in
            fileHandle.readabilityHandler = nil
        }
    }
}
