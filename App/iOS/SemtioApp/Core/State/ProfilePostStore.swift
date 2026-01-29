//
//  ProfilePostStore.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class ProfilePostStore: ObservableObject {

    @Published private(set) var posts: [Post] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasMore = true
    @Published private(set) var lastError: Error?

    private let repo: PostRepositoryProtocol
    private let pageSize = 15
    private var lastCursor: Any? = nil
    private var userId: String?

    init(repo: PostRepositoryProtocol) {
        self.repo = repo
    }

    func loadInitial(userId: String) async {
        guard !userId.isEmpty else {
            print("⚠️ ProfilePostStore: userId is empty, skipping load")
            return
        }
        self.userId = userId
        self.posts = []
        self.lastCursor = nil
        self.hasMore = true
        self.lastError = nil

        print("🔍 ProfilePostStore: loadInitial for userId=\(userId)")
        await fetchPosts()
    }

    func refresh() async {
        guard userId != nil else { return }
        self.lastCursor = nil
        self.hasMore = true
        await fetchPosts(isRefresh: true)
    }

    func loadMore() async {
        guard !isLoading, hasMore, userId != nil else { return }
        await fetchPosts()
    }

    func removePost(id: String) {
        posts.removeAll { $0.id == id }
    }

    private func fetchPosts(isRefresh: Bool = false) async {
        guard let userId = userId, !userId.isEmpty else {
            print("⚠️ ProfilePostStore: fetchPosts called with nil/empty userId")
            return
        }

        isLoading = true
        lastError = nil

        do {
            let result = try await repo.fetchPostsByUser(userId: userId, limit: pageSize, cursor: lastCursor)

            print("✅ ProfilePostStore: Fetched \(result.posts.count) posts for userId=\(userId), hasMore=\(result.hasMore)")

            if isRefresh {
                self.posts = result.posts
            } else {
                self.posts.append(contentsOf: result.posts)
            }

            self.lastCursor = result.cursor
            self.hasMore = result.hasMore

        } catch {
            self.lastError = error
            print("❌ ProfilePostStore: Failed to fetch posts for userId=\(userId): \(error.localizedDescription)")
            // Log full error for Firestore index issues
            print("❌ ProfilePostStore: Full error: \(error)")
        }

        isLoading = false
    }
}
