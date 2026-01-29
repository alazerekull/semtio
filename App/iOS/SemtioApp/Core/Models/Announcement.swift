//
//  Announcement.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

struct Announcement: Identifiable, Codable {
    let id: String
    let title: String
    let body: String
    let createdAt: Date
    var isActive: Bool
    let priority: Int?
    let actionURL: URL?
    
    // Convenience init
    init(id: String, title: String, body: String, createdAt: Date = Date(), isActive: Bool = true, priority: Int? = 0, actionURL: URL? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.isActive = isActive
        self.priority = priority
        self.actionURL = actionURL
    }
}
