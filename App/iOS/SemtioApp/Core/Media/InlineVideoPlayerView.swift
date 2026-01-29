//
//  InlineVideoPlayerView.swift
//  SemtioApp
//
//  Wraps AVPlayerViewController for inline playback without controls.
//

import SwiftUI
import AVKit

struct InlineVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.view.backgroundColor = .clear
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update player if changed (rare for our reuse key logic, but good practice)
        if uiViewController.player != player {
            uiViewController.player = player
        }
        uiViewController.videoGravity = .resizeAspectFill
    }
}
