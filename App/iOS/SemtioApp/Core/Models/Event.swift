//
//  Event.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

enum EventCategory: String, Codable, CaseIterable, Identifiable {
    case party, sport, music, food, meetup, other
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .party: return "Parti"
        case .sport: return "Spor"
        case .music: return "Müzik"
        case .food: return "Yemek"
        case .meetup: return "Buluşma"
        case .other: return "Diğer"
        }
    }
    
    var icon: String {
        switch self {
        case .party: return "party.popper.fill"
        case .sport: return "figure.run"
        case .music: return "music.note"
        case .food: return "fork.knife"
        case .meetup: return "person.2.fill"
        case .other: return "star.fill"
        }
    }
    
    var defaultImageName: String {
        switch self {
        case .party: return "party_default"
        case .sport: return "sport_default"
        case .music: return "music_default"
        case .food: return "food_default"
        case .meetup: return "meetup_default"
        case .other: return "other_default"
        }
    }
}

enum EventVisibility: String, Codable, CaseIterable, Identifiable {
    case `public`         // Herkese Açık - Direkt katılım
    case requestApproval  // Onaylı Katılım - İstek gönder, host onaylar
    case `private`        // Sadece Davetliler - Davet edilenler görebilir
    
    var id: String { rawValue }
    
    var localizedName: String {
        switch self {
        case .public: return "Herkese Açık"
        case .requestApproval: return "Onaylı Katılım"
        case .private: return "Sadece Davetliler"
        }
    }
    
    var icon: String {
        switch self {
        case .public: return "globe"
        case .requestApproval: return "lock.shield"
        case .private: return "person.2.slash"
        }
    }
    
    var description: String {
        switch self {
        case .public: return "Herkes direkt katılabilir"
        case .requestApproval: return "Katılım için onayınız gerekir"
        case .private: return "Sadece davet ettikleriniz görebilir"
        }
    }
}

enum EventStatus: String, Codable {
    case draft
    case published
    case cancelled
    
    var localizedName: String {
        switch self {
        case .draft: return "Taslak"
        case .published: return "Yayında"
        case .cancelled: return "İptal Edildi"
        }
    }
    
    var color: String { // Helper for UI color name or hex
        switch self {
        case .draft: return "gray"
        case .published: return "green"
        case .cancelled: return "red"
        }
    }
}

struct Event: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var description: String?
    var startDate: Date
    var endDate: Date?
    var locationName: String?
    var semtName: String?        // Legacy field, use district instead
    var hostUserId: String?      // Legacy field, use createdBy instead
    var participantCount: Int
    var coverColorHex: String?
    var category: EventCategory
    var lat: Double
    var lon: Double
    var coverImageURL: String?
    
    // Capacity management
    var capacityLimit: Int?
    
    // NEW FIELDS - Feature Set
    var tags: [String]           // e.g., ["outdoor", "music", "free"]
    var isFeatured: Bool         // Featured on dashboard
    var createdBy: String        // User ID who created (replaces hostUserId)
    var createdAt: Date          // Server timestamp
    var district: String?        // Semt/district name (replaces semtName)
    var visibility: EventVisibility
    var status: EventStatus = .published
    
    // SCHEMA FIELD ADDITIONS
    var rules: String?           // "Çadır getirmek"
    var isPaid: Bool = false
    var ticketPrice: Double = 0.0
    var isOnline: Bool = false
    var externalLink: String?
    
    // Participants - Single "Source of Truth" is attendees array for logic
    var attendees: [String] = []  // List of UIDs
    
    // UI Denormalized Data (Optional, for fast rendering)
    var usersJoined: [UserLite] = [] // Denormalized attendee objects
    
    // NEW FIELDS - Premium Boost
    var isBoosted: Bool = false
    var boostedUntil: Date?
    
    var isActive: Bool {
        let now = Date()
        let end = endDate ?? startDate.addingTimeInterval(2 * 60 * 60)
        return startDate <= now && end >= now
    }
    
    var isBoostedActive: Bool {
        guard isBoosted, let boostedUntil = boostedUntil else { return false }
        return boostedUntil > Date()
    }
    
    var isFull: Bool {
        guard let limit = capacityLimit, limit > 0 else { return false }
        return participantCount >= limit
    }
    
    var capacityProgress: Double {
        guard let limit = capacityLimit, limit > 0 else { return 0 }
        return min(1.0, Double(participantCount) / Double(limit))
    }
    
    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startDate)
    }
    
    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        if Calendar.current.isDateInToday(startDate) { return "Bugün" }
        if Calendar.current.isDateInTomorrow(startDate) { return "Yarın" }
        formatter.dateFormat = "EEEE"
        return formatter.string(from: startDate)
    }
    
    var isPast: Bool {
        let end = endDate ?? startDate.addingTimeInterval(2 * 60 * 60)
        return end < Date()
    }
    
    // Shareable URL
    var shareURL: URL? {
        URL(string: "https://semtio.app/event/\(id)")
    }
}
