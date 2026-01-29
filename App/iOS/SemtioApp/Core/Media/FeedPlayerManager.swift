//
//  FeedPlayerManager.swift
//  SemtioApp
//
//  Manage inline video players efficienty.
//

import AVFoundation
import Combine

/// Singleton manager for feed video players
class FeedPlayerManager: ObservableObject {
    static let shared = FeedPlayerManager()
    
    // Players cache: Key is usually postId
    private var players: [String: AVPlayer] = [:]
    
    // Track currently playing key
    @Published private(set) var currentPlayingKey: String?
    
    // Global mute state
    @Published var isMuted: Bool = true {
        didSet {
            updateMuteState()
        }
    }
    
    private let maxPlayerCount = 6
    private var lruKeys: [String] = [] // Recent keys for eviction
    
    private init() {
        // Observe system audio session if needed
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ FeedPlayerManager: Audio session error: \(error)")
        }
    }
    
    func player(for key: String, url: URL) -> AVPlayer {
        if let existing = players[key] {
            // Update usage for LRU
            touchKey(key)
            return existing
        }
        
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .pause // Loop logic handled by observer if needed, typically pause or replay
        player.isMuted = isMuted
        
        // Add to cache
        players[key] = player
        touchKey(key)
        
        // Evict if needed
        if players.count > maxPlayerCount {
            evictOldest()
        }
        
        return player
    }
    
    func isPlaying(_ key: String) -> Bool {
        guard let player = players[key] else { return false }
        return currentPlayingKey == key && player.rate != 0
    }
    
    func play(key: String) {
        // Pause others
        if let current = currentPlayingKey, current != key {
            players[current]?.pause()
        }
        
        if let player = players[key] {
            player.play()
            currentPlayingKey = key
        }
    }
    
    func pause(key: String) {
        players[key]?.pause()
        if currentPlayingKey == key {
            currentPlayingKey = nil
        }
    }
    
    func pauseAll(except exceptionKey: String? = nil) {
        for (key, player) in players {
            if key != exceptionKey {
                player.pause()
            }
        }
        if let current = currentPlayingKey, current != exceptionKey {
            currentPlayingKey = nil
        }
    }
    
    func toggleMute() {
        isMuted.toggle()
    }
    
    private func updateMuteState() {
        for player in players.values {
            player.isMuted = isMuted
        }
    }
    
    // MARK: - LRU Logic
    
    private func touchKey(_ key: String) {
        if let idx = lruKeys.firstIndex(of: key) {
            lruKeys.remove(at: idx)
        }
        lruKeys.append(key)
    }
    
    private func evictOldest() {
        guard let oldest = lruKeys.first else { return }
        // Don't evict if it's currently playing (unlikely if maxPlayerCount is reasonable)
        if oldest == currentPlayingKey { return }
        
        players.removeValue(forKey: oldest)
        lruKeys.removeFirst()
    }
}
