//
//  SavedEventsStore.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Manages saved/bookmarked events with Firestore persistence.
//

import SwiftUI
import Combine

@MainActor
final class SavedEventsStore: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var savedIds: Set<String> = []
    @Published private(set) var isLoading: Bool = false
    
    /// Per-event loading state for toggle operations
    @Published private(set) var loadingIds: Set<String> = []
    
    // MARK: - Dependencies
    
    private let repo: UserRepositoryProtocol
    private var currentUserId: String?
    
    // MARK: - Init
    
    init(repo: UserRepositoryProtocol) {
        self.repo = repo
    }
    
    // MARK: - Setup
    
    /// Sets the current user and loads their saved events
    func setUser(uid: String) async {
        currentUserId = uid
        isLoading = true
        
        do {
            savedIds = try await repo.fetchSavedEventIds(uid: uid)
        } catch {
            print("SavedEventsStore: Failed to load saved events: \(error)")
            savedIds = []
        }
        
        isLoading = false
    }
    
    /// Clears state on sign out
    func clearState() {
        currentUserId = nil
        savedIds = []
        loadingIds = []
        isLoading = false
    }
    
    // MARK: - Query
    
    /// Checks if an event is saved (from local cache)
    func isSaved(_ eventId: String) -> Bool {
        savedIds.contains(eventId)
    }
    
    /// Checks if save action is in progress for an event
    func isToggling(_ eventId: String) -> Bool {
        loadingIds.contains(eventId)
    }
    
    // MARK: - Actions
    
    /// Toggles save state with optimistic update
    func toggleSave(eventId: String) async {
        guard let uid = currentUserId else { return }
        
        // Prevent double-tap
        guard !loadingIds.contains(eventId) else { return }
        loadingIds.insert(eventId)
        
        let wasSaved = isSaved(eventId)
        
        // Optimistic update
        if wasSaved {
            savedIds.remove(eventId)
        } else {
            savedIds.insert(eventId)
        }
        
        do {
            if wasSaved {
                try await repo.unsaveEvent(eventId: eventId, uid: uid)
            } else {
                try await repo.saveEvent(eventId: eventId, uid: uid)
            }
        } catch {
            // Revert on failure
            if wasSaved {
                savedIds.insert(eventId)
            } else {
                savedIds.remove(eventId)
            }
            print("SavedEventsStore: Toggle save failed: \(error)")
        }
        
        loadingIds.remove(eventId)
    }
}
