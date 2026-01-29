//
//  User.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

// MARK: - AppUser Alias
typealias AppUser = User

struct User: Identifiable, Codable, Equatable {
    var id: String
    var fullName: String
    var avatarAssetName: String?   // Local asset
    var avatarURL: String?         // Remote URL (NEW)
    var headline: String?          // Bio/Status
    
    // Profile Completion Fields
    var username: String?
    var city: String?              // Legacy field, mapping to district
    var bio: String?
    var interests: [String]?
    var profileCompleted: Bool?    // Persisted flag
    var profileImageData: Data?    // Local data blob
    var isProfilePublic: Bool? = true // Privacy Setting (default true)
    var readReceiptsEnabled: Bool? = true // Görüldü bilgisi (WhatsApp style)
    

    // NEW: Requested Fields
    var shareCode11: String?       // e.g. "ABC-123"
    var district: String?          // Semt/District
    var isPremium: Bool?           // Premium status (optional, default nil) = nil
    var isDeleted: Bool?           // Soft Delete flag
    
    // Exact Schema additions
    var nickname: String?
    var age: Int?
    var eyeColor: String?
    var accountStatus: String?     // "active", etc.

    // Hidden Chat PIN Security (PBKDF2-SHA256)
    var hiddenPinHash: String?     // PBKDF2 hash of hidden chat PIN (hex)
    var hiddenPinSalt: String?     // Random salt for PBKDF2 (hex)
    var hiddenPinAlgo: String?     // Algorithm identifier: "pbkdf2_sha256"
    var hiddenPinSetAt: Date?      // When PIN was set
    var hiddenPinFailCount: Int?   // Failed attempt count
    var hiddenPinLockedUntil: Date? // Lockout timestamp if too many failures
    
    // SCHEMA: Social Graph & Stats
    // SCHEMA: Social Graph (Friends)
    var friends: Int = 0
    
    // Denormalized list for fast access/feed
    var friendIds: [String] = []
    
    // Activity
    var eventsCreated: [String] = [] // List of Event IDs
    var savedEventIds: [String] = [] // Explicit list as per schema to replace/augment separate collection logic if needed (UI uses separate fetch usually)
    
    // Computed: Display Name (mapped to fullName)
    var displayName: String {
        get { fullName }
        set { fullName = newValue }
    }
    
    // Helper
    var isProfileComplete: Bool {
        if let flag = profileCompleted, flag == true { return true }
        return !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (username?.isEmpty == false) &&
        (district?.isEmpty == false || city?.isEmpty == false)
    }
}
