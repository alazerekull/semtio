//
//  RepositoryFactory.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  CENTRALIZED REPOSITORY FACTORY
//  All repository instantiation happens here based on AppConfig.dataSource (resolved).
//  Views and ViewModels never know which implementation they're using.
//  NOTE: AppConfig.dataSource automatically returns .mock in SwiftUI Preview mode.
//

import Foundation

// MARK: - Repository Factory

/// Factory that creates the appropriate repository implementations based on AppConfig.dataSource.
/// This is the ONLY place where Mock vs Firestore decision is made.
/// The dataSource is resolved at runtime (supports Preview mode detection).
struct RepositoryFactory {
    
    /// Resolved data source (accounts for Preview mode)
    private static var resolvedDataSource: DataSourceMode {
        AppConfig.dataSource
    }
    
    // MARK: - User Repository
    
    /// Cached singleton for UserRepository
    private static var _cachedUserRepo: UserRepositoryProtocol?
    
    static func makeUserRepository() -> UserRepositoryProtocol {
        // Return singleton to enable proper caching
        if let existing = _cachedUserRepo {
            return existing
        }
        
        let upstream: UserRepositoryProtocol
        switch resolvedDataSource {
        case .mock:
            upstream = MockUserRepository()
        case .firestore:
            #if canImport(FirebaseFirestore)
            upstream = FirestoreUserRepository()
            #else
            print("⚠️ FirebaseFirestore not available, falling back to mock")
            upstream = MockUserRepository()
            #endif
        }
        
        // Wrap in cache layer
        let cached = CachedUserRepository(upstream: upstream)
        _cachedUserRepo = cached
        return cached
    }
    
    // MARK: - Event Repository
    
    static func makeEventRepository() -> EventRepositoryProtocol {
        switch resolvedDataSource {
        case .mock:
            return MockEventRepository()
        case .firestore:
            #if canImport(FirebaseFirestore)
            return FirestoreEventRepository()
            #else
            print("⚠️ FirebaseFirestore not available, falling back to mock")
            return MockEventRepository()
            #endif
        }
    }
    
    // MARK: - Chat Repository
    
    static func makeChatRepository() -> ChatRepositoryProtocol {
        switch resolvedDataSource {
        case .mock:
            return MockChatRepository()
        case .firestore:
            #if canImport(FirebaseFirestore)
            return FirestoreChatRepository()
            #else
            print("⚠️ FirebaseFirestore not available, falling back to mock")
            return MockChatRepository()
            #endif
        }
    }
    
    // MARK: - Friend Repository
    
    static func makeFriendRepository() -> FriendRepositoryProtocol {
        switch resolvedDataSource {
        case .mock:
            return MockFriendRepository()
        case .firestore:
            #if canImport(FirebaseFirestore)
            return FirestoreFriendRepository()
            #else
            print("⚠️ FirebaseFirestore not available, falling back to mock")
            return MockFriendRepository()
            #endif
        }
    }
    
    // MARK: - Announcement Repository
    
    static func makeAnnouncementRepository() -> AnnouncementRepositoryProtocol {
        switch resolvedDataSource {
        case .mock:
            return MockAnnouncementRepository()
        case .firestore:
            #if canImport(FirebaseFirestore)
            return FirestoreAnnouncementRepository()
            #else
            print("⚠️ FirebaseFirestore not available, falling back to mock")
            return MockAnnouncementRepository()
            #endif
        }
    }
    // MARK: - Post Repository
    
    static func makePostRepository() -> PostRepositoryProtocol {
        switch resolvedDataSource {
        case .mock:
            return MockPostRepository()
        case .firestore:
            #if canImport(FirebaseFirestore)
            return FirestorePostRepository()
            #else
            print("⚠️ FirebaseFirestore not available, falling back to mock")
            return MockPostRepository()
            #endif
        }
    }
    // MARK: - Follow Repository
    
    static func makeFollowRepository() -> FollowRepositoryProtocol {
        switch resolvedDataSource {
        case .mock:
            return MockFollowRepository()
        case .firestore:
            #if canImport(FirebaseFirestore)
            return FirestoreFollowRepository()
            #else
            print("⚠️ FirebaseFirestore not available, falling back to mock")
            return MockFollowRepository()
            #endif
        }
    }

    // MARK: - Notification Repository

    static func makeNotificationRepository() -> NotificationRepositoryProtocol {
        switch resolvedDataSource {
        case .mock:
            return MockNotificationRepository()
        case .firestore:
            #if canImport(FirebaseFirestore)
            return FirestoreNotificationRepository()
            #else
            print("⚠️ FirebaseFirestore not available, falling back to mock")
            return MockNotificationRepository()
            #endif
        }
    }
}
