//
//  FeedStore.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Instagram-like paginated event feed store with mode switching.
//

import SwiftUI
import Combine

@MainActor
final class FeedStore: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var feedEvents: [Event] = []
    @Published private(set) var isLoadingInitial: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedMode: FeedMode = .upcoming
    
    // MARK: - Pagination State
    
    private(set) var canLoadMore: Bool = true
    
    // MARK: - Configuration
    
    private let pageSize: Int = 10
    private let repo: EventRepositoryProtocol
    
    // MARK: - Init
    
    init(repo: EventRepositoryProtocol) {
        self.repo = repo
    }
    
    // MARK: - Public Methods
    
    /// Loads the initial page of feed events for the current mode
    func loadInitialFeed() async {
        guard !isLoadingInitial else { return }
        
        isLoadingInitial = true
        errorMessage = nil
        canLoadMore = true
        
        // Reset cursor for current mode
        repo.resetFeedCursor(mode: selectedMode)
        
        do {
            let result = try await repo.fetchFeedEvents(mode: selectedMode, limit: pageSize)
            feedEvents = result.events
            canLoadMore = result.hasMore
        } catch {
            errorMessage = error.localizedDescription
            feedEvents = []
            canLoadMore = false
        }
        
        isLoadingInitial = false
    }
    
    /// Loads the next page of feed events
    func loadMoreFeed() async {
        guard !isLoadingMore, !isLoadingInitial, canLoadMore else { return }
        
        isLoadingMore = true
        errorMessage = nil
        
        do {
            let result = try await repo.fetchFeedEvents(mode: selectedMode, limit: pageSize)
            feedEvents.append(contentsOf: result.events)
            canLoadMore = result.hasMore
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoadingMore = false
    }
    
    /// Refreshes the feed (pull-to-refresh)
    func refresh() async {
        repo.resetFeedCursor(mode: selectedMode)
        canLoadMore = true
        errorMessage = nil
        
        do {
            let result = try await repo.fetchFeedEvents(mode: selectedMode, limit: pageSize)
            feedEvents = result.events
            canLoadMore = result.hasMore
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Switches feed mode and reloads
    func switchMode(to mode: FeedMode) async {
        guard mode != selectedMode else { return }
        
        selectedMode = mode
        await loadInitialFeed()
    }
    
    // MARK: - Computed Properties
    
    var isEmpty: Bool {
        feedEvents.isEmpty && !isLoadingInitial
    }
    
    var hasEvents: Bool {
        !feedEvents.isEmpty
    }
}

// MARK: - FeedMode Extensions

extension FeedMode {
    var displayName: String {
        switch self {
        case .forYou: return "Senin İçin"
        case .upcoming: return "Yaklaşan"
        case .featured: return "Öne Çıkan"
        case .nearby: return "Yakınında"
        }
    }
    
    var icon: String {
        switch self {
        case .forYou: return "sparkles"
        case .upcoming: return "clock"
        case .featured: return "star.fill"
        case .nearby: return "mappin.circle"
        }
    }
}
