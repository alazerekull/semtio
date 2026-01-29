//
//  ChatThread.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

enum ChatType: String, Codable {
    case dm
    case group
    case event
    case support
}

struct ChatThread: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var type: ChatType
    var participants: [String] // User IDs
    var lastMessage: ChatMessage?
    var updatedAt: Date
    var title: String? // For group/event chats

    /// Unread message counts per user (keyed by uid)
    /// In Firestore: { "user1_uid": 3, "user2_uid": 0, ... }
    var unreadCounts: [String: Int]

    /// User IDs who have archived this thread
    var archivedBy: [String] = []

    /// User IDs who have deleted this thread (soft delete)
    var deletedBy: [String] = []

    /// User IDs who have muted this thread
    var mutedBy: [String] = []
    
    /// User IDs who have hidden this thread (password protected)
    var hiddenBy: [String] = []

    /// Creator ID for group chats
    var creatorId: String?

    /// Photo URL for group chats
    var photoURL: String?
    
    init(id: String, type: ChatType, participants: [String], lastMessage: ChatMessage? = nil, updatedAt: Date, title: String? = nil, unreadCounts: [String: Int] = [:], archivedBy: [String] = [], deletedBy: [String] = [], mutedBy: [String] = [], hiddenBy: [String] = [], creatorId: String? = nil, photoURL: String? = nil) {
        self.id = id
        self.type = type
        self.participants = participants
        self.lastMessage = lastMessage
        self.updatedAt = updatedAt
        self.title = title
        self.unreadCounts = unreadCounts
        self.archivedBy = archivedBy
        self.deletedBy = deletedBy
        self.mutedBy = mutedBy
        self.hiddenBy = hiddenBy
        self.creatorId = creatorId
        self.photoURL = photoURL
    }
    
    /// Returns unread count for a specific user
    func unreadCount(for userId: String) -> Int {
        unreadCounts[userId] ?? 0
    }
}
