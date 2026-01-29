//
//  FeedVideoPlayer.swift
//  SemtioApp
//
//  Created for Performance Optimization on 2026-01-27.
//

import SwiftUI
import AVKit

struct FeedVideoPlayer: View {
    let postId: String
    let videoURL: URL
    let onDoubleTap: () -> Void
    let onSingleTap: () -> Void
    
    // Isolate updates
    @ObservedObject private var coordinator = VideoPlaybackCoordinator.shared
    
    // Local player reference (acquired after debounce)
    @State private var player: AVPlayer?
    @State private var showHeart = false
    
    // Internal state for debounce
    @State private var loadTask: Task<Void, Never>?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            
            // Player Layer
            if let player = player {
                VideoPlayerLayerView(player: player)
                    .frame(maxWidth: .infinity)
                    .frame(height: 350)
                    .onVisibilityChange { fraction in
                        if fraction >= 0.7 { // Stricter visibility
                            coordinator.play(url: videoURL)
                        } else if fraction < 0.2 {
                            coordinator.pause(url: videoURL)
                        }
                    }
                    .transition(.opacity)
            } else {
                // Placeholder
                ZStack {
                    Rectangle()
                        .fill(AppColor.surface)
                    
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(height: 350)
            }
            
            // Heart Burst Overlay
            HeartBurstView(isPresented: $showHeart)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            
            // Mute Button (Only show if player is active)
            if player != nil {
                Button(action: {
                    withAnimation {
                        coordinator.toggleMute()
                    }
                }) {
                    Image(systemName: coordinator.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .padding(12)
            }
        }
        .contentShape(Rectangle())
        .onAppear {
            // DEBOUNCE: Only load if user stops here for > 200ms
            loadTask?.cancel()
            loadTask = Task {
                try? await Task.sleep(nanoseconds: 200 * 1_000_000)
                if !Task.isCancelled {
                   await MainActor.run {
                       // Acquire player via Coordinator
                       self.player = coordinator.player(for: videoURL)
                   }
                }
            }
        }
        .onDisappear {
            loadTask?.cancel()
            loadTask = nil
            coordinator.pause(url: videoURL)
            self.player = nil
        }
        .onTapGesture(count: 2) {
            showHeart = true
            onDoubleTap()
        }
        .onTapGesture(count: 1) {
            onSingleTap()
        }
    }
}
