//
//  ChatSummary.swift
//  SemtioApp
//
//  Created by Antigravity on 2026-01-20.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

struct ChatSummary: Identifiable, Equatable {
    let id: String
    let type: ChatType
    let title: String
    let avatarURL: String? // URL string or asset name logic
    let lastMessage: String?
    let lastMessageAt: Date
    let unreadCount: Int
    let eventId: String? // For event groups
    let memberIds: [String]
    
    // UI Helpers
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastMessageAt, relativeTo: Date())
    }
}
