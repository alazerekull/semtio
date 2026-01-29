//
//  ProfileViewModel.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var createdEvents: [Event] = []
    @Published var joinedEvents: [Event] = []
    @Published var friendCount: Int = 0
    @Published var postCount: Int = 0
    @Published var followerCount: Int = 0
    @Published var followingCount: Int = 0
    @Published var isLoading = false
    @Published var selectedTab: ProfileTab = .posts
    
    private let eventRepo: EventRepositoryProtocol
    private let friendRepo: FriendRepositoryProtocol
    private let postRepo: PostRepositoryProtocol
    private var userId: String
    
    enum ProfileTab: String, CaseIterable {
        case posts = "Paylaşımlar"
        case created = "Etkinlikler"
        case joined = "Katıldıklarım"
    }

    enum SavedTab: String, CaseIterable {
        case events = "Etkinlikler"
        case posts = "Gönderiler"
        
        var icon: String {
            switch self {
            case .events: return "calendar"
            case .posts: return "photo"
            }
        }
    }
    
    @Published var selectedSavedTab: SavedTab = .events
    
    init(eventRepo: EventRepositoryProtocol, friendRepo: FriendRepositoryProtocol, postRepo: PostRepositoryProtocol, userId: String) {
        self.eventRepo = eventRepo
        self.friendRepo = friendRepo
        self.postRepo = postRepo
        self.userId = userId
    }
    
    /// Call this to update the userId (e.g., after auth is confirmed)
    func setUserId(_ uid: String) {
        self.userId = uid
    }
    
    func loadProfileData() async {
        // Guard: Skip if no userId
        guard !userId.isEmpty else {
            print("⚠️ ProfileViewModel: userId is empty, skipping load")
            return
        }
        
        isLoading = true
        
        async let eventsTask: () = loadEvents()
        async let friendsTask: () = loadFriendCount()
        async let postsTask: () = loadPostCount()
        
        _ = await (eventsTask, friendsTask, postsTask)
        
        isLoading = false
    }
    
    private func loadEvents() async {
        do {
            // Created events
            createdEvents = try await eventRepo.fetchEvents(createdBy: userId)
            
            // Joined events (mock: all events except created by user)
            let allEvents = try await eventRepo.fetchEvents()
            joinedEvents = allEvents.filter { $0.createdBy != userId }
        } catch {
            print("ProfileViewModel: Failed to load events: \(error)")
        }
    }
    
    private func loadFriendCount() async {
        guard !userId.isEmpty else { return }
        do {
            let friendPage = try await friendRepo.fetchFriends(userId: userId, limit: 100, startAfter: nil)
            friendCount = friendPage.users.count
        } catch {
            print("ProfileViewModel: Failed to load friends: \(error)")
        }
    }
    
    private func loadPostCount() async {
        guard !userId.isEmpty else { return }
        do {
            postCount = try await postRepo.fetchPostCount(userId: userId)
            // Mock followers/following for now
            followerCount = 0
            followingCount = 0
        } catch {
            print("ProfileViewModel: Failed to load post count: \(error)")
        }
    }
    
    var currentTabEvents: [Event] {
        switch selectedTab {
        case .created:
            return createdEvents
        case .joined:
            return joinedEvents
        case .posts:
            return [] // Posts are handled separately via postCount/repo
        }
    }
    
    func incrementPostCount() {
        postCount += 1
    }
    
    func decrementPostCount() {
        postCount = max(0, postCount - 1)
    }
}
