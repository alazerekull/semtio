//
//  MemoryCache.swift
//  SemtioApp
//
//  Created by Semtio Architect on 2026.
//

import Foundation

/// A thread-safe in-memory cache with Time-To-Live (TTL) support.
final class MemoryCache {
    static let shared = MemoryCache()
    private let cache = NSCache<NSString, CacheEntry>()
    
    /// Inserts an object into the cache with a specified TTL.
    /// - Parameters:
    ///   - value: The value to cache (supports structs and classes).
    ///   - key: Unique key for the object.
    ///   - ttl: Time to live in seconds (default 300s / 5 mins).
    func insert(_ value: Any, forKey key: String, ttl: TimeInterval = 300) {
        let entry = CacheEntry(value: value, expiry: Date().addingTimeInterval(ttl))
        cache.setObject(entry, forKey: key as NSString)
    }
    
    /// Retrieves an value if it exists and hasn't expired.
    func get(forKey key: String) -> Any? {
        guard let entry = cache.object(forKey: key as NSString) else { return nil }
        
        if Date() > entry.expiry {
            cache.removeObject(forKey: key as NSString)
            return nil
        }
        return entry.value
    }
    
    /// Manually removes an object (e.g., on invalidation/update).
    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    /// Clears all objects.
    func removeAll() {
        cache.removeAllObjects()
    }
}

/// Internal wrapper for cached objects to track expiry.
class CacheEntry {
    let value: Any
    let expiry: Date
    
    init(value: Any, expiry: Date) {
        self.value = value
        self.expiry = expiry
    }
}
