//
//  Logging.swift
//  Capto
//
//  Created by Refactoring on 01/27/25.
//

import Foundation

#if DEBUG
private func debugLog(_ message: String, file: String = #file, line: Int = #line) {
    let fileName = (file as NSString).lastPathComponent
    print("[\(fileName):\(line)] \(message)")
}
#else
private func debugLog(_ message: String, file: String = #file, line: Int = #line) {
    // No-op in release builds
}
#endif

// Make it accessible throughout the app
func logDebug(_ message: String, file: String = #file, line: Int = #line) {
    debugLog(message, file: file, line: line)
}

