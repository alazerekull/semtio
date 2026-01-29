//
//  VideoPlaybackCoordinator.swift
//  SemtioApp
//
//  Created for Performance Optimization on 2026-01-27.
//

import AVFoundation
import Combine
import SwiftUI

/// Coordinator for managing video playback efficiency.
/// Enforces: 1 active player max, LRU cacheing, Audio session management.
final class VideoPlaybackCoordinator: ObservableObject {
    static let shared = VideoPlaybackCoordinator()
    
    // Configuration
    private let maxCacheSize = 3
    
    // State
    private var playerCache: [URL: AVPlayer] = [:]
    private var lruKeys: [URL] = []
    
    @Published private(set) var currentPlayingURL: URL?
    @Published var isMuted: Bool = true {
        didSet {
            updateMuteState()
        }
    }
    
    private init() {
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            // MixWithOthers to allow background music (Spotify etc.) to continue when muted
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            PerformanceLogger.shared.log("AudioSession error: \(error)", category: "Video")
        }
    }
    
    // MARK: - Player Access
    
    func player(for url: URL) -> AVPlayer {
        if let existing = playerCache[url] {
            touchLRU(url)
            return existing
        }
        
        PerformanceLogger.shared.start("CreatePlayer \(url.lastPathComponent)", category: "Video")
        
        let playerItem = AVPlayerItem(url: url)
        // Optimization: Don't buffer too much
        playerItem.preferredForwardBufferDuration = 3.0
        playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        
        let player = AVPlayer(playerItem: playerItem)
        player.isMuted = isMuted
        player.actionAtItemEnd = .pause // We manage looping manually if needed
        
        // Cache
        playerCache[url] = player
        touchLRU(url)
        
        // Evict if needed
        if playerCache.count > maxCacheSize {
            evictOldest()
        }
        
        PerformanceLogger.shared.end("CreatePlayer \(url.lastPathComponent)", category: "Video")
        Task { @MainActor in PerformanceLogger.activePlayersCount = playerCache.count }
        
        return player
    }
    
    // MARK: - Control
    
    func play(url: URL) {
        // Pause others
        if let current = currentPlayingURL, current != url {
            playerCache[current]?.pause()
        }
        
        if let player = playerCache[url] {
            player.play()
            currentPlayingURL = url
            PerformanceLogger.shared.log("Playing \(url.lastPathComponent)", category: "Video")
        }
    }
    
    func pause(url: URL) {
        playerCache[url]?.pause()
        if currentPlayingURL == url {
            currentPlayingURL = nil
        }
    }
    
    func pauseAll() {
        playerCache.values.forEach { $0.pause() }
        currentPlayingURL = nil
    }
    
    func toggleMute() {
        isMuted.toggle()
    }
    
    // MARK: - Internals
    
    private func updateMuteState() {
        playerCache.values.forEach { $0.isMuted = isMuted }
    }
    
    private func touchLRU(_ url: URL) {
        if let idx = lruKeys.firstIndex(of: url) {
            lruKeys.remove(at: idx)
        }
        lruKeys.append(url)
    }
    
    private func evictOldest() {
        guard let oldest = lruKeys.first else { return }
        
        // Don't evict playing video
        if oldest == currentPlayingURL {
            // Try second oldest
            if lruKeys.count > 1 {
                let second = lruKeys[1]
                playerCache.removeValue(forKey: second)
                lruKeys.remove(at: 1)
            }
            return
        }
        
        playerCache.removeValue(forKey: oldest)
        lruKeys.removeFirst()
    }
}
