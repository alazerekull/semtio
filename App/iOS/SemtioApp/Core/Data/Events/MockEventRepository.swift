//
//  MockEventRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

final class MockEventRepository: EventRepository {
    private var events: [Event] = []
    
    // Internal cursor state per mode
    private var feedOffsets: [FeedMode: Int] = [:]
    
    init() {
        // Generate mock data
        let now = Date()
        let hour = 3600.0
        
        events = [
            Event(id: "1", title: "Yazılım Buluşması", startDate: now.addingTimeInterval(hour * 2), endDate: now.addingTimeInterval(hour * 4), locationName: "Kadiköy", semtName: "Kadıköy", participantCount: 42, coverColorHex: "007AFF", category: .meetup, lat: 41.0082, lon: 29.0284, capacityLimit: nil, tags: ["tech", "networking"], isFeatured: true, createdBy: "user1", createdAt: now, district: "Kadıköy", visibility: .public, rules: nil, isPaid: false, ticketPrice: 0, isOnline: false, externalLink: nil, attendees: [], usersJoined: []),
            Event(id: "2", title: "Yoga Workshop", startDate: now.addingTimeInterval(hour * 3), endDate: now.addingTimeInterval(hour * 4.5), locationName: "Cihangir Parkı", semtName: "Beyoğlu", participantCount: 15, coverColorHex: "FF9500", category: .sport, lat: 41.0382, lon: 28.9884, capacityLimit: 20, tags: ["wellness", "outdoor"], isFeatured: false, createdBy: "user2", createdAt: now, district: "Beyoğlu", visibility: .public, rules: "Mat getirmek zorunludur", isPaid: true, ticketPrice: 150.0, isOnline: false, externalLink: nil, attendees: [], usersJoined: []),
            Event(id: "3", title: "Akşam Koşusu", startDate: now.addingTimeInterval(hour * 5), endDate: now.addingTimeInterval(hour * 6), locationName: "Sahil", semtName: "Beşiktaş", participantCount: 8, coverColorHex: "34C759", category: .sport, lat: 41.0482, lon: 29.0084, capacityLimit: nil, tags: ["running", "fitness"], isFeatured: false, createdBy: "user3", createdAt: now, district: "Beşiktaş", visibility: .public, rules: nil, isPaid: false, ticketPrice: 0, isOnline: false, externalLink: nil, attendees: [], usersJoined: []),
            Event(id: "4", title: "Kahve Tadımı", startDate: now.addingTimeInterval(hour * 24), endDate: now.addingTimeInterval(hour * 26), locationName: "Espresso Lab", semtName: "Ataşehir", participantCount: 20, coverColorHex: "A2845E", category: .food, lat: 40.9982, lon: 29.1084, capacityLimit: 25, tags: ["coffee", "tasting"], isFeatured: true, createdBy: "user4", createdAt: now, district: "Ataşehir", visibility: .public, rules: nil, isPaid: true, ticketPrice: 300.0, isOnline: false, externalLink: nil, attendees: [], usersJoined: []),
            Event(id: "5", title: "Indie Rock Gecesi", startDate: now.addingTimeInterval(hour * 30), endDate: now.addingTimeInterval(hour * 34), locationName: "Blind", semtName: "Şişli", participantCount: 150, coverColorHex: "AF52DE", category: .music, lat: 41.0582, lon: 28.9984, capacityLimit: 200, tags: ["music", "live", "indie"], isFeatured: true, createdBy: "user5", createdAt: now, district: "Şişli", visibility: .public, rules: "+18", isPaid: true, ticketPrice: 400.0, isOnline: false, externalLink: nil, attendees: [], usersJoined: []),
            Event(id: "6", title: "Kitap Kulübü", startDate: now.addingTimeInterval(hour * 1), endDate: now.addingTimeInterval(hour * 3), locationName: "Minoa", semtName: "Beşiktaş", participantCount: 6, coverColorHex: "FF2D55", category: .other, lat: 41.0452, lon: 29.0054, capacityLimit: 10, tags: ["books", "reading"], isFeatured: false, createdBy: "user6", createdAt: now, district: "Beşiktaş", visibility: .public, rules: nil, isPaid: false, ticketPrice: 0, isOnline: false, externalLink: nil, attendees: [], usersJoined: []),
            Event(id: "7", title: "Start-up Networking", startDate: now.addingTimeInterval(hour * 0.5), endDate: now.addingTimeInterval(hour * 2), locationName: "Kolektif House", semtName: "Şişli", participantCount: 80, coverColorHex: "5856D6", category: .meetup, lat: 41.0782, lon: 29.0184, capacityLimit: 100, tags: ["startup", "business"], isFeatured: false, createdBy: "user7", createdAt: now, district: "Şişli", visibility: .public, rules: nil, isPaid: false, ticketPrice: 0, isOnline: false, externalLink: nil, attendees: [], usersJoined: [])
        ]
    }
    
    func fetchEvents() async throws -> [Event] {
        try? await Task.sleep(nanoseconds: 500_000_000)
        return events
    }

    func fetchEvent(eventId: String) async throws -> Event {
        try? await Task.sleep(nanoseconds: 300_000_000)
        if let event = events.first(where: { $0.id == eventId }) {
            return event
        }
        throw NSError(domain: "MockEventRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Event not found"])
    }
    
    func fetchActiveEvents() async throws -> [Event] {
        try? await Task.sleep(nanoseconds: 300_000_000)
        return events.filter { $0.isActive }
    }
    
    // v2.1 Protocol Impl
    func fetchTrending(limit: Int) async throws -> [Event] {
        try? await Task.sleep(nanoseconds: 300_000_000)
        let active = events.filter { $0.isActive }
        // Sort by participant count as mock score
        return Array(active.sorted { $0.participantCount > $1.participantCount }.prefix(limit))
    }
    
    func fetchEvents(bySemt semt: String) async throws -> [Event] {
         try? await Task.sleep(nanoseconds: 300_000_000)
         return events.filter { $0.semtName == semt && $0.isActive }
    }
    
    // Formerly deprecated featured
    func fetchEvents(byDistrict district: String) async throws -> [Event] {
        try? await Task.sleep(nanoseconds: 300_000_000)
        return events.filter { $0.district == district && !$0.isPast }
    }
    

    
    func fetchEvents(byCategory category: EventCategory) async throws -> [Event] {
        try? await Task.sleep(nanoseconds: 300_000_000)
        return events.filter { $0.category == category && !$0.isPast }
    }
    
    func fetchEvents(createdBy userId: String) async throws -> [Event] {
        try? await Task.sleep(nanoseconds: 300_000_000)
        return events.filter { $0.createdBy == userId }
    }
    
    func createEvent(_ event: Event) async throws {
        try? await Task.sleep(nanoseconds: 500_000_000)
        events.append(event)
    }
    
    func updateEvent(id: String, data: [String: Any]) async throws {
        try? await Task.sleep(nanoseconds: 500_000_000)
        guard let index = events.firstIndex(where: { $0.id == id }) else { return }
        
        var event = events[index]
        if let title = data["title"] as? String { event.title = title }
        if let desc = data["description"] as? String { event.description = desc }
        events[index] = event
    }
    
    func deleteEvent(id: String) async throws {
        try? await Task.sleep(nanoseconds: 500_000_000)
        events.removeAll { $0.id == id }
    }
    
    func listenEvents(district: String?, onChange: @escaping ([Event]) -> Void, onError: @escaping (Error) -> Void) -> AnyObject? {
        var result = events.filter { $0.isActive }
        if let district = district {
            result = result.filter { $0.district == district }
        }
        onChange(result)
        return nil
    }
    
    func stopListening(_ token: AnyObject?) {
         // No-op
    }
    
    func fetchEvents(filter: EventFilter) async throws -> [Event] {
        try? await Task.sleep(nanoseconds: 300_000_000)
        return events.filter { !$0.isPast }
    }
    
    // MARK: - Paginated Feed (Internal Cursor)
    
    func fetchFeedEvents(mode: FeedMode, limit: Int) async throws -> FeedPageResult {
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        let now = Date()
        let offset = feedOffsets[mode] ?? 0
        
        // Get filtered and sorted events based on mode
        var filteredEvents: [Event]
        
        switch mode {
        case .forYou:
            filteredEvents = events.filter { !$0.isPast }
        case .upcoming:
            filteredEvents = events.filter { $0.startDate >= now && !$0.isPast }
        case .featured:
            // reuse trending logic
            filteredEvents = events.filter { $0.isFeatured && !$0.isPast }
        case .nearby:
            filteredEvents = events.filter { $0.district == "Beşiktaş" && !$0.isPast }
        }
        
        // Apply pagination
        let startIndex = offset
        guard startIndex < filteredEvents.count else {
            return FeedPageResult(events: [], hasMore: false)
        }
        
        let endIndex = min(startIndex + limit, filteredEvents.count)
        let page = Array(filteredEvents[startIndex..<endIndex])
        let hasMore = endIndex < filteredEvents.count
        
        feedOffsets[mode] = endIndex
        return FeedPageResult(events: page, hasMore: hasMore)
    }
    
    func resetFeedCursor(mode: FeedMode) {
        feedOffsets[mode] = 0
    }
    
    // MARK: - Participation
    
    func joinEvent(eventId: String, uid: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
    
    func leaveEvent(eventId: String, uid: String) async throws {
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
    
    func isUserJoined(eventId: String, uid: String) async throws -> Bool {
        return false
    }
    
    func fetchJoinedEvents(uid: String) async throws -> [Event] {
        return []
    }
    
    func fetchPendingJoinedEvents(uid: String) async throws -> [Event] {
        return []
    }
    
    // MARK: - Premium Features
    
    func boostEvent(eventId: String) async throws -> Date {
        return Date().addingTimeInterval(86400)
    }
    
    func fetchBoostedUpcomingEvents(limit: Int) async throws -> [Event] {
        return []
    }
    
    // MARK: - Saved Events
    
    func saveEvent(eventId: String, userId: String) async throws {}
    func unsaveEvent(eventId: String, userId: String) async throws {}
    func isEventSaved(eventId: String, userId: String) async throws -> Bool { return false }
    func fetchSavedEvents(userId: String) async throws -> [Event] { return [] }
    
    // MARK: - Event Management
    func cancelEvent(eventId: String) async throws {}
    
    // MARK: - Join Requests
    
    func submitJoinRequest(eventId: String, userId: String, userName: String, userAvatarURL: String?) async throws {}
    func respondToJoinRequest(eventId: String, requestId: String, approve: Bool, note: String?) async throws {}
    func fetchPendingJoinRequests(eventId: String) async throws -> [JoinRequest] { return [] }
    func getJoinRequestStatus(eventId: String, userId: String) async throws -> JoinRequestStatus? { return nil }
    
    // MARK: - Invites
    
    func createInviteLink(eventId: String) async throws -> String {
        return "semtio://invite"
    }
    
    func joinWithInvite(token: String) async throws -> String {
        return "1"
    }

    // MARK: - Event Chat
    
    func sendEventMessage(eventId: String, text: String, sender: UserLite) async throws {
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
    
    func listenEventMessages(eventId: String, onChange: @escaping ([ChatMessage]) -> Void) -> AnyObject? {
        // Return some mock messages
        let now = Date()
        let msgs = [
            ChatMessage(id: "1", threadId: eventId, text: "Merhaba, etkinlik ne zaman başlıyor?", senderId: "user2", createdAt: now.addingTimeInterval(-3600)),
            ChatMessage(id: "2", threadId: eventId, text: "Saat 20:00'de!", senderId: "user1", createdAt: now.addingTimeInterval(-1800))
        ]
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            onChange(msgs)
        }
        return nil
    }
}
