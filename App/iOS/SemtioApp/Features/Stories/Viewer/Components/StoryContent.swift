//
//  StoryContent.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import AVKit

struct StoryContent: View {
    let story: Story
    var isPaused: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            if story.mediaType == .image {
                AsyncImage(url: URL(string: story.mediaURL)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        Color.gray
                            .overlay(ProgressView())
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            } else {
                if let url = URL(string: story.mediaURL) {
                    StoryVideoPlayer(videoURL: url, isPaused: isPaused)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            }
        }
    }
}

// Custom Video Player for Stories (Instagram-like)
struct StoryVideoPlayer: UIViewRepresentable {
    let videoURL: URL
    let isPaused: Bool
    
    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        
        let player = AVPlayer(url: videoURL)
        player.actionAtItemEnd = .none // Handle looping manually
        view.player = player
        
        // Setup looping
        context.coordinator.setupLooping(for: player)
        
        // Mute logic? Stories usually play sound if not silent mode.
        // Assuming default audio session handled globally.
        
        player.play()
        return view
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {
        if isPaused {
            uiView.player?.pause()
        } else {
            uiView.player?.play()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var looper: NSObjectProtocol?
        
        func setupLooping(for player: AVPlayer) {
            // Remove existing observer if any (not strictly needed for one-shot makes)
            looper = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }
        
        deinit {
            if let looper = looper {
                NotificationCenter.default.removeObserver(looper)
            }
        }
    }
}

class PlayerView: UIView {
    var player: AVPlayer? {
        get { return playerLayer.player }
        set { playerLayer.player = newValue }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        playerLayer.videoGravity = .resizeAspectFill
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
