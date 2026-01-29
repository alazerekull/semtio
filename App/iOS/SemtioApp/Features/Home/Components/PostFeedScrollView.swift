//
//  PostFeedScrollView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct PostFeedScrollView: View {
    let posts: [Post]
    let isLoadingMore: Bool
    let hasMore: Bool
    let onRefresh: () async -> Void
    let onLoadMore: () async -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                    postRow(index: index, post: post)
                }
                
                if isLoadingMore {
                    ProgressView()
                        .padding()
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            await onRefresh()
        }
        .onDisappear {
            FeedPlayerManager.shared.pauseAll()
        }
    }
    
    @ViewBuilder
    private func postRow(index: Int, post: Post) -> some View {
        Group {
            if post.type == .standard {
                PostCardView(post: post)
            } else {
                ActivityPostView(post: post)
            }
        }
        .onAppear {
            if index >= posts.count - 3 && hasMore && !isLoadingMore {
                Task { await onLoadMore() }
            }
        }
    }
}
