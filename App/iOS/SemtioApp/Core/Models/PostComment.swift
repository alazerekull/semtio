//
//  PostComment.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

struct PostComment: Identifiable, Codable, Equatable {
    let id: String
    let postId: String
    let uid: String
    let username: String?
    let userDisplayName: String?
    let userAvatarURL: String?
    let text: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId
        case uid
        case username
        case userDisplayName
        case userAvatarURL
        case text
        case createdAt
    }
}
