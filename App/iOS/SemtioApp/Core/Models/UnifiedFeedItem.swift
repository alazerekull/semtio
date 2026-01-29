//
//  UnifiedFeedItem.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

/// Application-side model representing a resolved feed item.
enum UnifiedFeedItem: Identifiable {
    case post(Post)
    case event(Event)
    // case sponsor(AdModel) - Future
    
    var id: String {
        switch self {
        case .post(let post): return post.id
        case .event(let event): return event.id
        }
    }
    
    var createdAt: Date {
        switch self {
        case .post(let post): return post.createdAt
        case .event(let event): return event.createdAt
        }
    }
}
