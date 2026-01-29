//
//  FeedViewModel.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import Combine
import FirebaseFirestore

@MainActor
final class FeedViewModel: ObservableObject {
    
    // MARK: - Published State
    @Published var items: [UnifiedFeedItem] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var hasMore = true
    @Published var currentFilter: PostFeedStore.FeedFilter = .following
    
    // MARK: - Private State
    private let repo: FeedRepositoryProtocol
    private let postRepo: PostRepositoryProtocol
    private let eventRepo: EventRepositoryProtocol
    private var lastSnapshot: DocumentSnapshot?
    private let pageSize = 15
    
    private var followingIds: [String] = []
    
    // MARK: - Init
    init(repo: FeedRepositoryProtocol, postRepo: PostRepositoryProtocol = FirestorePostRepository(), eventRepo: EventRepositoryProtocol = FirestoreEventRepository()) {
        self.repo = repo
        self.postRepo = postRepo
        self.eventRepo = eventRepo
    }
    
    // MARK: - API Methods
    
    func updateFollowingIds(_ ids: [String]) {
        self.followingIds = ids
    }
    
    func setFilter(_ filter: PostFeedStore.FeedFilter) async {
        guard currentFilter != filter else { return }
        currentFilter = filter
        // Clear items immediately to show transition
        items = []
        isLoading = true 
        await refresh()
    }
    
    func fetchInitial() async {
        guard items.isEmpty, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            switch currentFilter {
            case .following:
                if !followingIds.isEmpty {
                    // Fetch Friend Posts
                    let result = try await postRepo.fetchPostsByAuthors(authorIds: followingIds, limit: pageSize, cursor: nil)
                    self.items = result.posts.map { UnifiedFeedItem.post($0) }
                    self.lastSnapshot = result.cursor as? DocumentSnapshot
                    self.hasMore = result.hasMore
                } else {
                    // Following but no friends -> Empty or Suggestion
                    self.items = [] 
                    self.hasMore = false
                }
            case .recent:
                // Global Unified Feed (Discover)
                // Fetch posts
                async let postsTask = postRepo.fetchFeedPosts(limit: pageSize, cursor: nil)
                // Fetch public events (limited batch)
                async let eventsTask = eventRepo.fetchActiveEvents()
                
                let (postsResult, events) = try await (postsTask, eventsTask)
                
                let postItems = postsResult.posts.map { UnifiedFeedItem.post($0) }
                let eventItems = events.map { UnifiedFeedItem.event($0) }
                
                // Mix and sort by date descending (Newest content first)
                let combined = (postItems + eventItems).sorted { $0.createdAt > $1.createdAt }
                
                self.items = combined
                self.lastSnapshot = postsResult.cursor as? DocumentSnapshot
                self.hasMore = postsResult.hasMore
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func fetchMore() async {
        guard !isLoading, hasMore, let lastSnapshot = lastSnapshot else { return }
        isLoading = true
        
        do {
            switch currentFilter {
            case .following:
                if !followingIds.isEmpty {
                     let result = try await postRepo.fetchPostsByAuthors(authorIds: followingIds, limit: pageSize, cursor: lastSnapshot)
                     let newItems = result.posts.map { UnifiedFeedItem.post($0) }
                     self.items.append(contentsOf: newItems)
                     self.lastSnapshot = result.cursor as? DocumentSnapshot
                     self.hasMore = result.hasMore
                }
            case .recent:
                let result = try await postRepo.fetchFeedPosts(limit: pageSize, cursor: lastSnapshot)
                let newItems = result.posts.map { UnifiedFeedItem.post($0) }
                self.items.append(contentsOf: newItems)
                self.lastSnapshot = result.cursor as? DocumentSnapshot
                self.hasMore = result.hasMore
            }
        } catch {
            // Silently fail or show small error toast
            print("Feed fetchMore error: \(error)")
        }
        
        isLoading = false
    }
    
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        do {
            self.lastSnapshot = nil
            
            switch currentFilter {
            case .following:
                if !followingIds.isEmpty {
                    let result = try await postRepo.fetchPostsByAuthors(authorIds: followingIds, limit: pageSize, cursor: nil)
                    self.items = result.posts.map { UnifiedFeedItem.post($0) }
                    self.lastSnapshot = result.cursor as? DocumentSnapshot
                    self.hasMore = result.hasMore
                } else {
                    self.items = []
                    self.hasMore = false
                }
            case .recent:
                // Fetch posts
                async let postsTask = postRepo.fetchFeedPosts(limit: pageSize, cursor: nil)
                // Fetch public events
                async let eventsTask = eventRepo.fetchActiveEvents()
                
                let (postsResult, events) = try await (postsTask, eventsTask)
                
                let postItems = postsResult.posts.map { UnifiedFeedItem.post($0) }
                let eventItems = events.map { UnifiedFeedItem.event($0) }
                
                let combined = (postItems + eventItems).sorted { $0.createdAt > $1.createdAt }
                
                self.items = combined
                self.lastSnapshot = postsResult.cursor as? DocumentSnapshot
                self.hasMore = postsResult.hasMore
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isRefreshing = false
    }
    
    // MARK: - Interaction Handlers (Delegates to global stores or Repos)
    
    /// Called when an item is deleted or hidden
    func removeItem(id: String) {
        items.removeAll { item in
            switch item {
            case .post(let p): return p.id == id
            case .event(let e): return e.id == id
            }
        }
    }
}
