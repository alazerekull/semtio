//
//  PostMediaView.swift
//  SemtioApp
//
//  Created for Performance Optimization on 2026-01-27.
//

import SwiftUI

struct PostMediaView: View, Equatable {
    let postId: String
    let mediaType: Post.MediaType
    let mediaURL: URL?
    let isLiked: Bool // For initial state only, optimistic updates handled via callbacks or injected binding if needed, but here simple props.
    
    // Actions
    let onDoubleTap: () -> Void
    let onSingleTap: () -> Void
    
    static func == (lhs: PostMediaView, rhs: PostMediaView) -> Bool {
        return lhs.postId == rhs.postId &&
               lhs.mediaURL == rhs.mediaURL &&
               lhs.isLiked == rhs.isLiked // Re-render if like status changes? Maybe expensive. Ideally handled internally or overlaid.
    }
    
    @State private var showHeart = false
    
    var body: some View {
        Group {
            if let url = mediaURL {
                if mediaType == .video {
                    FeedVideoPlayer(
                        postId: postId,
                        videoURL: url,
                        onDoubleTap: onDoubleTap,
                        onSingleTap: onSingleTap
                    )
                } else {
                    // Image
                    ZStack(alignment: .center) {
                        CachedRemoteImage(url: url, targetSize: CGSize(width: 1080, height: 1350))
                            .frame(maxWidth: .infinity)
                            .frame(height: 350)
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                showHeart = true
                                onDoubleTap()
                            }
                        
                        HeartBurstView(isPresented: $showHeart)
                            .allowsHitTesting(false)
                    }
                }
            } else {
                Color.gray.opacity(0.1).frame(height: 350)
            }
        }
    }
}
