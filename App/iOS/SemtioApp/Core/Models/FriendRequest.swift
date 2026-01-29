//
//  FriendRequest.swift
//  SemtioApp
//
//  Friend request data model for pending/accepted/rejected/cancelled requests.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct FriendRequest: Identifiable, Codable, Equatable {
    let id: String
    let fromUid: String
    let toUid: String
    let status: String  // pending, accepted, rejected, cancelled
    let createdAt: Date?
    let updatedAt: Date?
    
    // Optional denormalized fields for UI display
    var fromName: String?
    var fromAvatar: String?
    var toName: String?
    var toAvatar: String?
    
    init(
        id: String,
        fromUid: String,
        toUid: String,
        status: String,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        fromName: String? = nil,
        fromAvatar: String? = nil,
        toName: String? = nil,
        toAvatar: String? = nil
    ) {
        self.id = id
        self.fromUid = fromUid
        self.toUid = toUid
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.fromName = fromName
        self.fromAvatar = fromAvatar
        self.toName = toName
        self.toAvatar = toAvatar
    }
    
    #if canImport(FirebaseFirestore)
    /// Creates a FriendRequest from a Firestore DocumentSnapshot
    static func fromDoc(_ doc: DocumentSnapshot) -> FriendRequest? {
        guard let data = doc.data() else { return nil }
        
        let id = (data["id"] as? String) ?? doc.documentID
        guard
            let fromUid = data["fromUid"] as? String,
            let toUid = data["toUid"] as? String,
            let status = data["status"] as? String
        else { return nil }
        
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        
        return FriendRequest(
            id: id,
            fromUid: fromUid,
            toUid: toUid,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            fromName: data["fromName"] as? String,
            fromAvatar: data["fromAvatar"] as? String,
            toName: data["toName"] as? String,
            toAvatar: data["toAvatar"] as? String
        )
    }
    #endif
    
    // MARK: - Status Helpers
    
    var isPending: Bool { status == "pending" }
    var isAccepted: Bool { status == "accepted" }
    var isRejected: Bool { status == "rejected" }
    var isCancelled: Bool { status == "cancelled" }
}

// MARK: - Request Status Enum

enum FriendRequestStatus: String, Codable {
    case pending
    case accepted
    case rejected
    case cancelled
}
