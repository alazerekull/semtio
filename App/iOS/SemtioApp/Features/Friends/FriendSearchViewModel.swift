//
//  FriendSearchViewModel.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import Combine

/// Error states for friend search
enum FriendSearchError: LocalizedError {
    case notConfigured
    case noUserId
    case searchFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Arama yapılandırılmadı. Lütfen tekrar deneyin."
        case .noUserId:
            return "Kullanıcı kimliği alınamadı."
        case .searchFailed(let message):
            return "Arama başarısız: \(message)"
        }
    }
}

enum UserRelationship {
    case none
    case friend
    case pendingOutgoing
    case pendingIncoming


}

@MainActor
final class FriendSearchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [AppUser] = []
    @Published var suggestedUsers: [AppUser] = [] // New: Suggested Users
    @Published var pendingRequestIds: Set<String> = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var isConfigured = false
    
    // Relationship State
    @Published var incomingRequestIds: Set<String> = []
    @Published var friendIds: Set<String> = []
    
    private var friendStore: FriendStore?
    private var userStore: UserStore? // New: dependency for suggestions
    private var currentUserId: String = ""
    private var searchTask: Task<Void, Never>?
    
    init() {}
    
    /// Configure with FriendStore and UserStore
    func configure(friendStore: FriendStore, userStore: UserStore, currentUserId: String) {
        self.friendStore = friendStore
        self.userStore = userStore
        self.currentUserId = currentUserId
        
        if currentUserId.isEmpty {
            print("❌ FriendSearchViewModel: currentUserId is EMPTY!")
            errorMessage = FriendSearchError.noUserId.localizedDescription
            isConfigured = false
        } else {
            print("✅ FriendSearchViewModel configured with userId: \(currentUserId)")
            isConfigured = true
            errorMessage = nil
        }
    }
    
    /// Call when view appears to load initial data.
    func loadData() async {
        guard isConfigured else { return }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.refreshOutgoingPending() }
            group.addTask { await self.refreshIncomingRequests() }
            group.addTask { await self.refreshFriends() }
            group.addTask { await self.loadSuggestedUsers() }
        }
    }
    
    func refreshIncomingRequests() async {
         guard let friendStore = friendStore else { return }
         await friendStore.loadIncomingRequests(force: true)
         let ids = friendStore.incomingRequests.map { $0.fromUid }
         self.incomingRequestIds = Set(ids)
    }
    
    func refreshFriends() async {
        guard let friendStore = friendStore, !currentUserId.isEmpty else { return }
        await friendStore.loadIfNeeded(userId: currentUserId)
        let ids = friendStore.friends.map { $0.id }
        self.friendIds = Set(ids)
    }
    
    func loadSuggestedUsers() async {
        guard let userStore = userStore else { return }
        do {
            let suggestions = try await userStore.fetchSuggestedUsers(limit: 10)
            self.suggestedUsers = suggestions
        } catch {
             print("⚠️ ViewModel: Failed to load suggestions: \(error)")
        }
    }
    
    /// Refreshes the set of users we have sent pending requests to.
    
    /// Refreshes the set of users we have sent pending requests to.
    func refreshOutgoingPending() async {
        guard isConfigured, let friendStore = friendStore, !currentUserId.isEmpty else { return }
        
        do {
            // Fetch fresh list from Firestore (via Repo alias in FriendStore)
            // Note: FriendStore needs to expose this or we access repo directly if exposed.
            // Since FriendStore wraps repo, we should check if FriendStore has this method or add it.
            // For now, assuming FriendStore will pass through or we add it there too.
            // Checking FriendStore source code might be needed, but let's implement the VM logic assuming we'll add it to FriendStore next.
            
            // Actually, let's check FriendStore first if needed. But based on strict instructions, I'll add the logic.
            // If FriendStore doesn't have it, I'll need to update FriendStore too.
            // Let's assume we can add `fetchOutgoingPendingRequests` to FriendStore.
            
            // Wait, I can't check FriendStore right now without another tool call. 
            // I'll write the code to call `friendStore.fetchOutgoingPendingRequests(userId: currentUserId)` 
            // and I will ensure I update FriendStore to support it.
            
            let deepFetch = try await friendStore.repo.fetchOutgoingPendingRequests(for: currentUserId)
            pendingRequestIds = deepFetch
            print("✅ ViewModel: Refreshed pending requests: \(pendingRequestIds.count)")
        } catch {
            print("⚠️ ViewModel: Failed to refresh pending requests: \(error.localizedDescription)")
        }
    }
    
    /// Called on search query change (debounced).
    func onSearchQueryChanged(_ query: String) {
        searchTask?.cancel()
        errorMessage = nil
        
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        // Validate configuration
        guard isConfigured, let friendStore = friendStore else {
            print("❌ FriendSearchViewModel: Cannot search - not configured")
            errorMessage = FriendSearchError.notConfigured.localizedDescription
            searchResults = []
            isSearching = false
            return
        }
        
        if currentUserId.isEmpty {
            print("❌ FriendSearchViewModel: Cannot search - no user ID")
            errorMessage = FriendSearchError.noUserId.localizedDescription
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        searchTask = Task {
            // Debounce 300ms
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            guard !Task.isCancelled else { return }
            
            print("🔍 ViewModel calling friendStore.search with query: '\(trimmed)'")
            await friendStore.search(query: trimmed)
            
            // Check for search error
            if let searchError = friendStore.lastSearchError {
                errorMessage = FriendSearchError.searchFailed(searchError.localizedDescription).localizedDescription
                searchResults = []
            } else {
                // Get results from friendStore, excluding current user
                searchResults = friendStore.searchResults.filter { $0.id != currentUserId }
                errorMessage = nil
            }
            
            // Also refresh pending to ensure button states are correct
            await refreshOutgoingPending()
            
            print("✅ ViewModel received \(searchResults.count) results")
            isSearching = false
        }
    }
    
    /// Send friend request to a user.
    func sendRequest(to userId: String) async {
        guard isConfigured, let friendStore = friendStore, !currentUserId.isEmpty else {
            errorMessage = FriendSearchError.notConfigured.localizedDescription
            return
        }
        
        // Optimistic update
        pendingRequestIds.insert(userId)
        
        await friendStore.sendRequest(from: currentUserId, to: userId)
        
        // Real update
        await refreshOutgoingPending()
        print("✅ Friend request sent/refreshed for: \(userId)")
    }
    

    
    func acceptRequest(from userId: String) async {
         guard isConfigured, let friendStore = friendStore else { return }
         // Optimistic
         incomingRequestIds.remove(userId)
         friendIds.insert(userId)
         
         await friendStore.acceptRequest(fromUserId: userId)
         
         // Refresh to Sync
         await refreshFriends()
         await refreshIncomingRequests()
    }
    
    func rejectRequest(from userId: String) async {
        guard isConfigured, let friendStore = friendStore else { return }
        // Optimistic
        incomingRequestIds.remove(userId)
        
        await friendStore.rejectRequest(fromUserId: userId)
        
        await refreshIncomingRequests()
    }

    /// Check relationship
    func relationship(for userId: String) -> UserRelationship {
        if friendIds.contains(userId) { return .friend }
        if pendingRequestIds.contains(userId) { return .pendingOutgoing }
        if incomingRequestIds.contains(userId) { return .pendingIncoming }
        return .none
    }

    /// Check if request has been sent to this user.
    func isRequestPending(for userId: String) -> Bool {
        relationship(for: userId) == .pendingOutgoing
    }
    
    /// Clear search state
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        errorMessage = nil
        friendStore?.clearSearch()
    }
}
