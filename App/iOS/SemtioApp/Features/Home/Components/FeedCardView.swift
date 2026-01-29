//
//  FeedCardView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct FeedCardView: View {
    let item: UnifiedFeedItem
    
    var body: some View {
        switch item {
        case .post(let post):
            PostCardView(post: post)
                .id("post_\(post.id)")
            
        case .event(let event):
            EventPostCard(event: event)
                .id("event_\(event.id)")
                .padding(.vertical, 8) // Add some spacing for event cards to stand out
        }
    }
}
