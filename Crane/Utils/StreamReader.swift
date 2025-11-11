//
//  LineReader.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 10/11/25.
//

// Source - https://stackoverflow.com/a
// Posted by Martin R, modified by community. See post 'Timeline' for change history
// Retrieved 2025-11-10, License - CC BY-SA 3.0

import Foundation

class StreamReader {
    let encoding: String.Encoding
    let chunkSize: Int
    
    var fileHandle: FileHandle!
    var buffer: Data!
    let delimData: Data!
    var atEof: Bool = false
    
    init?(fileHandle: FileHandle, delimiter: String = "\n", encoding: String.Encoding = .utf8, chunkSize: Int = 4096) {
        self.chunkSize = chunkSize
        self.encoding = encoding
        self.fileHandle = fileHandle
        self.delimData = delimiter.data(using: encoding)
        self.buffer = Data()
    }
    
    deinit {
        close()
    }
    
    /// Return next line, or nil on EOF.
    func nextLine() -> String? {
        precondition(fileHandle != nil, "Attempt to read from closed file")
        
        if atEof {
            return nil
        }
        
        // Read data chunks from file until a line delimiter is found:
        var range = buffer.range(of: delimData, in: 0..<buffer.count)
        while range == nil {
            let tmpData = fileHandle.readData(ofLength: chunkSize)
            if tmpData.isEmpty {
                // EOF or read error.
                atEof = true
                if !buffer.isEmpty {
                    // Buffer contains last line in file (not terminated by delimiter).
                    if let line = String(data: buffer, encoding: encoding) {
                        buffer.removeAll()
                        return line
                    }
                }
                // No more lines.
                return nil
            }
            buffer.append(tmpData)
            range = buffer.range(of: delimData, in: 0..<buffer.count)
        }
        
        guard let range = range else { return nil }
        
        // Convert complete line (excluding the delimiter) to a string:
        if let line = String(data: buffer[0..<range.lowerBound], encoding: encoding) {
            // Remove line (and the delimiter) from the buffer:
            buffer.replaceSubrange(0..<range.upperBound, with: [])
            return line
        }
        
        return nil
    }
    
    /// Start reading from the beginning of file.
    func rewind() {
        fileHandle.seek(toFileOffset: 0)
        buffer.removeAll()
        atEof = false
    }
    
    func skipLines(_ n: Int) {
        for _ in 0..<n {
            guard let _ = nextLine() else {
                return
            }
        }
    }
    
    /// Close the underlying file. No reading must be done after calling this method.
    func close() {
        fileHandle?.closeFile()
        fileHandle = nil
    }
}
