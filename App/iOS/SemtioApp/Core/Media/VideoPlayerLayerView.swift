//
//  VideoPlayerLayerView.swift
//  SemtioApp
//
//  Created for Performance Optimization on 2026-01-27.
//

import SwiftUI
import AVFoundation

struct VideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill
    
    func makeUIView(context: Context) -> PlayerUIView {
        return PlayerUIView(player: player, videoGravity: videoGravity)
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.update(player: player, videoGravity: videoGravity)
    }
    
    // UIKit View Class
    class PlayerUIView: UIView {
        var playerLayer: AVPlayerLayer {
            return layer as! AVPlayerLayer
        }
        
        override static var layerClass: AnyClass {
            return AVPlayerLayer.self
        }
        
        init(player: AVPlayer, videoGravity: AVLayerVideoGravity) {
            super.init(frame: .zero)
            self.playerLayer.player = player
            self.playerLayer.videoGravity = videoGravity
            self.backgroundColor = .black
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(player: AVPlayer, videoGravity: AVLayerVideoGravity) {
            if playerLayer.player != player {
                playerLayer.player = player
            }
            if playerLayer.videoGravity != videoGravity {
                playerLayer.videoGravity = videoGravity
            }
        }
    }
}
