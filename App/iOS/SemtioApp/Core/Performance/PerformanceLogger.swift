//
//  PerformanceLogger.swift
//  SemtioApp
//
//  Created for Performance Optimization on 2026-01-27.
//

import Foundation
import OSLog

final class PerformanceLogger {
    static let shared = PerformanceLogger()
    
    // Subsystems
    private let feedLoad = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.semtio.app", category: "FeedLoad")
    private let media = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.semtio.app", category: "MediaPipeline")
    private let video = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.semtio.app", category: "VideoPlayback")
    
    // Signpost IDs
    private var signpostIDs: [String: OSSignpostID] = [:]
    private let lock = NSLock()
    
    // Counters
    @MainActor static var activePlayersCount = 0
    @MainActor static var visibleCellsCount = 0
    
    private init() {}
    
    func start(_ name: String, category: String = "General") {
        let log = logFor(category)
        let id = OSSignpostID(log: log)
        lock.lock()
        signpostIDs[name] = id
        lock.unlock()
        
        os_signpost(.begin, log: log, name: "Operation", signpostID: id, "%{public}s started", name)
    }
    
    func end(_ name: String, category: String = "General") {
        lock.lock()
        let id = signpostIDs.removeValue(forKey: name)
        lock.unlock()
        
        if let id = id {
            let log = logFor(category)
            os_signpost(.end, log: log, name: "Operation", signpostID: id, "%{public}s ended", name)
        }
    }
    
    func log(_ message: String, category: String = "General") {
        let log = logFor(category)
        os_log("%{public}s", log: log, type: .debug, message)
    }
    
    private func logFor(_ category: String) -> OSLog {
        switch category {
        case "FeedLoad": return feedLoad
        case "Media": return media
        case "Video": return video
        default: return .default
        }
    }
}
