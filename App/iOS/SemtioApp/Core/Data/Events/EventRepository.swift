//
//  EventRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

// MARK: - Feed Mode

/// Defines different feed modes for pagination
enum FeedMode: String, CaseIterable {
    case forYou       // Personalized/all events
    case upcoming     // Events starting soon (soonest first)
    case featured     // Deprecated in favor of Trending (metrics.score)
    case nearby       // Events in user's district
}

// MARK: - Feed Page Result

struct FeedPageResult {
    let events: [Event]
    let hasMore: Bool
}

// MARK: - Event Repository Protocol

protocol EventRepositoryProtocol {
    // Core fetch methods
    func fetchEvents() async throws -> [Event]
    func fetchEvent(eventId: String) async throws -> Event
    func fetchActiveEvents() async throws -> [Event]
    
    // Feature Set
    func fetchTrending(limit: Int) async throws -> [Event]
    func fetchEvents(byDistrict district: String) async throws -> [Event]
    func fetchEvents(bySemt semt: String) async throws -> [Event]
    func fetchEvents(createdBy uid: String) async throws -> [Event]
    
    // Flexible filter-based fetch
    func fetchEvents(filter: EventFilter) async throws -> [Event]
    
    // Paginated feed fetch (cursor managed internally)
    func fetchFeedEvents(mode: FeedMode, limit: Int) async throws -> FeedPageResult
    func resetFeedCursor(mode: FeedMode)
    
    // CRUD
    func createEvent(_ event: Event) async throws
    func updateEvent(id: String, data: [String: Any]) async throws
    func deleteEvent(id: String) async throws
    
    // Real-time
    func listenEvents(district: String?, onChange: @escaping ([Event]) -> Void, onError: @escaping (Error) -> Void) -> AnyObject?
    func stopListening(_ token: AnyObject?)
    
    // MARK: - Participation
    
    func joinEvent(eventId: String, uid: String) async throws
    func leaveEvent(eventId: String, uid: String) async throws
    func isUserJoined(eventId: String, uid: String) async throws -> Bool
    func fetchJoinedEvents(uid: String) async throws -> [Event]
    func fetchPendingJoinedEvents(uid: String) async throws -> [Event]
    
    // MARK: - Premium Features
    
    func boostEvent(eventId: String) async throws -> Date
    func fetchBoostedUpcomingEvents(limit: Int) async throws -> [Event]
    
    // MARK: - Saved Events
    
    func saveEvent(eventId: String, userId: String) async throws
    func unsaveEvent(eventId: String, userId: String) async throws
    func isEventSaved(eventId: String, userId: String) async throws -> Bool
    func fetchSavedEvents(userId: String) async throws -> [Event]
    
    // MARK: - Event Management (V2)
    func cancelEvent(eventId: String) async throws
    
    // MARK: - Join Requests
    
    func submitJoinRequest(eventId: String, userId: String, userName: String, userAvatarURL: String?) async throws
    func respondToJoinRequest(eventId: String, requestId: String, approve: Bool, note: String?) async throws
    func fetchPendingJoinRequests(eventId: String) async throws -> [JoinRequest]
    func getJoinRequestStatus(eventId: String, userId: String) async throws -> JoinRequestStatus?
    
    // MARK: - Invites
    
    func createInviteLink(eventId: String) async throws -> String
    func joinWithInvite(token: String) async throws -> String
    // MARK: - Event Chat
    
    func sendEventMessage(eventId: String, text: String, sender: UserLite) async throws
    func listenEventMessages(eventId: String, onChange: @escaping ([ChatMessage]) -> Void) -> AnyObject?

}

// Legacy alias
typealias EventRepository = EventRepositoryProtocol
