//
//  InflightTaskCoalescer.swift
//  SemtioApp
//
//  Created by Semtio Architect on 2026.
//

import Foundation

/// Prevents redundant network calls for identical requests by coalescing inflight tasks.
/// Useful for things like profile fetches in a feed where the same user appears multiple times.
actor InflightTaskCoalescer {
    private var activeTasks: [String: Task<Any, Error>] = [:]
    
    /// Performs an operation only if one is not already in progress for the given key.
    /// If one is in progress, waits for it and returns its result.
    func perform<T>(key: String, operation: @escaping () async throws -> T) async throws -> T {
        if let existing = activeTasks[key] {
            return try await existing.value as! T
        }
        
        let task = Task {
            try await operation()
        }
        
        // Store the type-erased task
        // We cast T to Any to store it in the dictionary
        activeTasks[key] = Task {
            try await task.value
        }
        
        // Cleanup after finish (success or failure)
        _ = await task.result
        activeTasks[key] = nil
        
        return try await task.value
    }
}
