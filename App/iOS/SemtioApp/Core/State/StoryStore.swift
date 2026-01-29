//
//  StoryStore.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import SwiftUI

@MainActor
class StoryStore: ObservableObject {
    
    struct UserStoryBundle: Identifiable {
        let user: AppUser
        var stories: [Story]
        
        var id: String { user.id }
        
        var hasUnseen: Bool {
            stories.contains { !$0.isViewed }
        }
        
        var latestDate: Date {
            stories.last?.createdAt ?? Date.distantPast
        }
    }
    
    @Published var storyBundles: [UserStoryBundle] = []
    @Published var myStories: [Story] = []
    @Published var isLoading = false

    private let repo: StoryRepositoryProtocol
    private let userStore: UserStore
    private let followRepo: FollowRepositoryProtocol

    init(repo: StoryRepositoryProtocol, userStore: UserStore, followRepo: FollowRepositoryProtocol = FirestoreFollowRepository()) {
        self.repo = repo
        self.userStore = userStore
        self.followRepo = followRepo
    }
    
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        let myId = userStore.currentUser.id
        guard !myId.isEmpty else { return }

        do {
            // 1. Fetch My Stories
            let fetchedMyStories = try await repo.fetchStories(userIds: [myId])
            self.myStories = fetchedMyStories

            // 2. Collect user IDs from both friends AND following
            var userIdsToFetch = Set<String>()

            // 2a. Add friends
            if userStore.friends.isEmpty {
                await userStore.fetchFriends()
            }
            let friendIds = userStore.friends.map { $0.id }
            userIdsToFetch.formUnion(friendIds)

            // 2b. Add following (people I follow)
            do {
                let followingIds = try await followRepo.fetchFollowingIds(userId: myId)
                userIdsToFetch.formUnion(followingIds)
            } catch {
                print("⚠️ StoryStore: Failed to fetch following list: \(error)")
            }

            // 3. Fetch stories for all collected user IDs
            let allUserIds = Array(userIdsToFetch)
            if !allUserIds.isEmpty {
                await loadStories(for: allUserIds)
            } else {
                self.storyBundles = []
            }

        } catch {
            print("❌ StoryStore: Failed to fetch my stories: \(error)")
        }
    }
    
    func loadStories(for userIds: [String]) async {
        guard !userIds.isEmpty else { return }
        
        do {
            let stories = try await repo.fetchStories(userIds: userIds)
            
            var bundles: [UserStoryBundle] = []
            
            // Group stories by ownerId
            let grouped = Dictionary(grouping: stories, by: { $0.ownerId })
            
            for (uid, userStories) in grouped {
                // Optimize: check friends list first, then fetch if needed
                if let friend = userStore.friends.first(where: { $0.id == uid }) {
                    bundles.append(UserStoryBundle(user: friend, stories: userStories))
                } else if let user = try? await userStore.fetchUser(uid) {
                     bundles.append(UserStoryBundle(user: user, stories: userStories))
                }
            }
            
            // Sort bundles: Has unseen first, then by date logic?
            self.storyBundles = bundles.sorted { 
                if $0.hasUnseen && !$1.hasUnseen { return true }
                if !$0.hasUnseen && $1.hasUnseen { return false }
                return $0.latestDate > $1.latestDate
            }
            
        } catch {
            print("❌ StoryStore: Failed to load stories: \(error)")
        }
    }
    
    func markAsViewed(storyId: String) {
        let currentUser = userStore.currentUser
        guard !currentUser.id.isEmpty else { return }

        // Find the story and its owner
        var storyOwnerId: String?
        for bundle in storyBundles {
            if bundle.stories.contains(where: { $0.id == storyId }) {
                storyOwnerId = bundle.user.id
                break
            }
        }

        // Don't record view for own stories
        guard let ownerId = storyOwnerId, ownerId != currentUser.id else { return }

        // Optimistically update local state to viewed
        for i in 0..<storyBundles.count {
            if let sIdx = storyBundles[i].stories.firstIndex(where: { $0.id == storyId }) {
                // Skip if already viewed
                guard !storyBundles[i].stories[sIdx].isViewed else { return }
                storyBundles[i].stories[sIdx].isViewed = true
                break
            }
        }

        // Record view in backend (fire and forget)
        Task {
            do {
                try await repo.recordView(
                    storyId: storyId,
                    storyOwnerId: ownerId,
                    viewerId: currentUser.id,
                    viewerName: currentUser.fullName,
                    viewerAvatar: currentUser.avatarURL
                )
            } catch {
                print("⚠️ StoryStore: Failed to record view: \(error)")
            }
        }
    }

    /// Fetches viewers for a story (for story owner)
    func fetchViewers(for story: Story) async -> [StoryViewer] {
        do {
            return try await repo.fetchViewers(storyId: story.id, storyOwnerId: story.ownerId)
        } catch {
            print("❌ StoryStore: Failed to fetch viewers: \(error)")
            return []
        }
    }
    
    func deleteStory(storyId: String) async {
        let myId = userStore.currentUser.id
        guard !myId.isEmpty else { return }
        
        // Optimistic UI Update first? Or wait for success? 
        // Better wait for success for deletion usually, but instant feel is nice.
        
        do {
            try await repo.deleteStory(storyId: storyId, userId: myId)
            
            // Update Local State
            self.myStories.removeAll { $0.id == storyId }
            
            // Also update any bundle that might represent 'Me' or if I viewed my own story in a bundle
            if let bundleIndex = storyBundles.firstIndex(where: { $0.user.id == myId }) {
                storyBundles[bundleIndex].stories.removeAll { $0.id == storyId }
                if storyBundles[bundleIndex].stories.isEmpty {
                    storyBundles.remove(at: bundleIndex)
                }
            }
            
        } catch {
             print("❌ Failed to delete story: \(error)")
        }
    }
}
