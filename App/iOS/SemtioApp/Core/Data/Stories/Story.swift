//
//  Story.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import FirebaseFirestore

struct Story: Identifiable, Codable {
    let id: String
    let ownerId: String
    
    // Media
    let mediaURL: String
    let thumbURL: String?
    let mediaType: MediaType
    
    // Content
    let caption: String
    let context: StoryContext
    let visibility: StoryVisibility
    
    // Metadata
    let createdAt: Date
    let expiresAt: Date
    let viewCount: Int
    
    // Client-side status
    var isViewed: Bool = false
    
    enum MediaType: String, Codable {
        case image
        case video
    }
    
    enum StoryVisibility: String, Codable {
        case `public`
        case followers
        case closeFriends = "close_friends"
    }
    
    enum StoryContext: Codable, Equatable {
        case none
        case event(id: String, name: String, date: Date, imageURL: String?)
        
        // Custom coding keys for Firestore union
        enum CodingKeys: String, CodingKey {
            case type
            case eventId
            case eventName
            case eventDate
            case eventImageURL
        }
        
        init(from decoder: Decoder) throws {
             let container = try decoder.container(keyedBy: CodingKeys.self)
             let type = try container.decode(String.self, forKey: .type)
             
             switch type {
             case "event":
                 let id = try container.decode(String.self, forKey: .eventId)
                 let name = try container.decode(String.self, forKey: .eventName)
                 let date = try container.decode(Date.self, forKey: .eventDate)
                 let imageURL = try container.decodeIfPresent(String.self, forKey: .eventImageURL)
                 self = .event(id: id, name: name, date: date, imageURL: imageURL)
             default:
                 self = .none
             }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .none:
                try container.encode("none", forKey: .type)
            case .event(let id, let name, let date, let imageURL):
                try container.encode("event", forKey: .type)
                try container.encode(id, forKey: .eventId)
                try container.encode(name, forKey: .eventName)
                try container.encode(date, forKey: .eventDate)
                try container.encodeIfPresent(imageURL, forKey: .eventImageURL)
            }
        }
    }
}
