//
//  EventInteractionStore.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Manages local state for event join/leave interactions.
//  Provides optimistic UI updates with repository sync.
//  NOTE: Save/bookmark functionality moved to SavedEventsStore.
//

import SwiftUI
import Combine

@MainActor
final class EventInteractionStore: ObservableObject {
    
    // MARK: - Published State
    
    /// Set of event IDs the current user has joined (local cache)
    @Published private(set) var joinedEventIds: Set<String> = []
    
    /// Loading states per event
    @Published private(set) var loadingJoin: Set<String> = []
    
    // MARK: - Dependencies
    
    private let repo: EventRepositoryProtocol
    private var currentUserId: String?
    
    // MARK: - Init
    
    init(repo: EventRepositoryProtocol) {
        self.repo = repo
    }
    
    // MARK: - Setup
    
    /// Sets the current user ID and loads their joined events
    func setUser(uid: String) async {
        currentUserId = uid
        await loadJoinedEvents()
    }
    
    /// Clears state on sign out
    func clearState() {
        currentUserId = nil
        joinedEventIds = []
        loadingJoin = []
    }
    
    // MARK: - Join/Leave
    
    /// Checks if user has joined an event (from local cache)
    func isJoined(_ eventId: String) -> Bool {
        joinedEventIds.contains(eventId)
    }
    
    /// Toggles join state for an event with optimistic update
    func toggleJoin(event: Event) async {
        guard let uid = currentUserId else { return }
        let eventId = event.id
        
        // Prevent double-tap
        guard !loadingJoin.contains(eventId) else { return }
        loadingJoin.insert(eventId)
        
        let wasJoined = isJoined(eventId)
        
        // Optimistic update
        if wasJoined {
            joinedEventIds.remove(eventId)
        } else {
            joinedEventIds.insert(eventId)
        }
        
        do {
            if wasJoined {
                try await repo.leaveEvent(eventId: eventId, uid: uid)
            } else {
                try await repo.joinEvent(eventId: eventId, uid: uid)
            }
        } catch {
            // Revert on failure
            if wasJoined {
                joinedEventIds.insert(eventId)
            } else {
                joinedEventIds.remove(eventId)
            }
            print("EventInteractionStore: Toggle join failed: \(error)")
        }
        
        loadingJoin.remove(eventId)
    }
    
    /// Checks if join action is in progress for an event
    func isJoinLoading(_ eventId: String) -> Bool {
        loadingJoin.contains(eventId)
    }
    
    /// Explicitly join an event (for notifications/invites)
    func joinEvent(eventId: String) async {
        guard let uid = currentUserId else { return }
        
        // Optimistic
        if !joinedEventIds.contains(eventId) {
            joinedEventIds.insert(eventId)
        }
        
        do {
            try await repo.joinEvent(eventId: eventId, uid: uid)
        } catch {
            joinedEventIds.remove(eventId) // Revert
            print("EventInteractionStore: Failed to join event from invite: \(error)")
        }
    }
    
    // MARK: - Private
    
    private func loadJoinedEvents() async {
        guard let uid = currentUserId else { return }
        
        do {
            let events = try await repo.fetchJoinedEvents(uid: uid)
            joinedEventIds = Set(events.map { $0.id })
        } catch {
            print("EventInteractionStore: Failed to load joined events: \(error)")
        }
    }
    // MARK: - Likes
    
    // NOTE: Unlike Join, Like persistence isn't fully implemented in this store.
    // This is a placeholder for the EventPostCard logic.
    // Real implementation should sync with a LikeRepository or reuse SavedEventsStore if 'like' == 'save'.
    
    func likeEvent(eventId: String, uid: String) async throws {
        // Placeholder: No-op or call repository
    }
    
    func unlikeEvent(eventId: String, uid: String) async throws {
        // Placeholder
    }
}
