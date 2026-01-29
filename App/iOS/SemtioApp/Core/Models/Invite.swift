//
//  Invite.swift
//  SemtioApp
//
//  Created for Events V2 Feature.
//

import Foundation

enum InviteStatus: String, Codable {
    case pending
    case accepted
    case declined
}

struct Invite: Identifiable, Codable {
    let id: String
    let eventId: String
    let fromUserId: String
    let toUserId: String
    let message: String?
    var status: InviteStatus
    let createdAt: Date
    
    // De-normalized data for UI ease
    var eventTitle: String?
    var fromUserName: String?
}
