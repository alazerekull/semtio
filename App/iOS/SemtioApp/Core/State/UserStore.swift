//
//  UserStore.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import Combine
import SwiftUI


@MainActor
final class UserStore: ObservableObject {
    // Current Legacy User (Mapping to new profile where possible for backward compat during migration)
    @Published var currentUser: User
    
    // NEW: User Profile (Source of Truth)
    @Published var currentUserProfile: UserProfile?
    
    @Published var isLoading: Bool = false
    @Published private(set) var isLoadingProfile: Bool = false
    
    // We can still use AppStorage for local fast check, but source of truth is Firestore
    @AppStorage("user.profileComplete") var profileCompleteStorage: Bool = false
    
    let repo: UserRepositoryProtocol
    
    // Debug
    @Published var lastSaveStatus: String = "None"

    // Saved Posts
    @Published private(set) var savedPostIds: Set<String> = []

    private var listener: AnyObject?
    
    var isProfileComplete: Bool {
        currentUser.isProfileComplete || profileCompleteStorage
    }
    
    /// Safe avatar URL for UI (only http/https, filters mock:// URLs)
    var avatarURLForUI: URL? {
        guard let urlString = currentUser.avatarURL, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }
    
    /// Safe avatar URL from profile (only http/https)
    var profileAvatarURLForUI: URL? {
        guard let urlString = currentUserProfile?.avatarURL, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }
    
    func resolveUserByUsername(_ username: String) async -> AppUser? {
        do {
            return try await repo.fetchUser(username: username)
        } catch {
            print("❌ UserStore: Failed to resolve user by username '\(username)': \(error)")
            return nil
        }
    }
    
    func fetchUser(_ id: String) async throws -> AppUser? {
        return try await repo.fetchUser(id: id)
    }
    
    init(repo: UserRepositoryProtocol) {
        self.repo = repo
        // Start with a placeholder user
        self.currentUser = User(
            id: "",
            fullName: "Kullanıcı",
            avatarAssetName: "avatar_placeholder",
            headline: nil,
            username: nil,
            city: nil,
            bio: nil,
            interests: []
        )
    }
    
    // MARK: - Suggestions
    
    func fetchSuggestedUsers(limit: Int) async throws -> [AppUser] {
        return try await repo.fetchSuggestedUsers(limit: limit)
    }
    
    func startListening(uid: String) {
        guard !uid.isEmpty else {
            print("⚠️ UserStore: Cannot start listening with empty uid")
            return
        }
        
        stopListening()
        
        // Sync legacy user id
        currentUser.id = uid
        
        print("👂 UserStore: Starting listener for uid: \(uid.prefix(8))")
        
        // Listen to new UserProfile via shared Repo
        listener = repo.listenUser(id: uid) { [weak self] user in
            Task { @MainActor in
                guard let self = self, let user = user else { return }
                
                print("📩 UserStore: Received update for uid: \(uid.prefix(8))")
                
                // Map User -> UserProfile
                self.currentUserProfile = UserProfile(
                    id: user.id,
                    displayName: user.fullName,
                    bio: user.bio,
                    avatarURL: user.avatarURL,
                    isProfilePublic: user.isProfilePublic ?? true,
                    readReceiptsEnabled: user.readReceiptsEnabled ?? true,
                    postCount: 0, // Placeholder
                    followersCount: 0,
                    followingCount: 0,
                    eventCount: 0,
                    joinCount: 0,
                    friendCount: 0,
                    username: user.username == nil || user.username?.isEmpty == true ? nil : user.username,
                    city: user.city,
                    interests: user.interests ?? [],
                    shareCode11: user.shareCode11
                )
                
                // Sync legacy object
                self.currentUser = user
                self.profileCompleteStorage = user.isProfileComplete
                
                // Initialize Socials
                self.listenFriendRequests()
                await self.fetchFriends()

                // Load saved posts
                await self.loadSavedPostIds()
            }
        } onError: { error in
            print("❌ UserStore listener error: \(error)")
        }
    }
    
    func stopListening() {
        if let listener = listener {
            print("🛑 UserStore: Stopping listener")
            repo.removeListener(listener)
            self.listener = nil
        }
        currentUserProfile = nil
    }
    
    // MARK: - User Doc Guarantee
    
    /// Ensures users/{uid} exists and has all required fields.
    func syncAuthUser(uid: String, email: String?, displayName: String?) async {
        guard !uid.isEmpty else {
            print("❌ UserStore: Cannot sync auth user with empty uid")
            return
        }
        
        print("═══════════════════════════════════════════════════════")
        print("👤 SYNC AUTH USER (Repo Proxy) - uid:", uid)
        print("═══════════════════════════════════════════════════════")
        
        // Delegate entirely to repository which handles Mock vs Firestore logic
        do {
            try await repo.upsertUser(id: uid, email: email, displayName: displayName)
            print("✅ SYNC AUTH USER COMPLETE for uid:", uid)
        } catch {
            print("❌ SYNC AUTH USER FAILED:", error.localizedDescription)
            // Surface error to UI if needed
        }
        
        startListening(uid: uid)
    }
    
    /// Guarantees that users/{uid} exists.
    func createUserDocIfMissing(uid: String, email: String?, displayName: String?) async {
        // Delegate to syncAuthUser
        await syncAuthUser(uid: uid, email: email, displayName: displayName)
    }
    
    func updateName(_ name: String) {
        currentUser.fullName = name
    }
    
    func saveProfile(displayName: String, username: String? = nil, bio: String?, avatarImage: UIImage?, isProfilePublic: Bool, readReceiptsEnabled: Bool = true) async {
        guard let uid = currentUserProfile?.id ?? (currentUser.id.isEmpty ? nil : currentUser.id) else {
            print("⚠️ UserStore.saveProfile: No user ID available")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        var data: [String: Any] = [
            "displayName": displayName,
            "bio": bio ?? "",
            "isProfilePublic": isProfilePublic,
            "readReceiptsEnabled": readReceiptsEnabled
        ]
        
        if let username = username, !username.isEmpty {
            data["username"] = username
        }
        
        // Upload avatar if provided
        if let image = avatarImage {
            do {
                let url = try await AvatarStorageService.shared.uploadAvatar(uid: uid, image: image)
                data["avatarURL"] = url
                // Update local immediately
                currentUser.avatarURL = url
            } catch {
                print("⚠️ UserStore: Failed to upload avatar: \(error)")
                // Continue saving other fields
            }
        }
        
        // Persist to Firestore
        do {
            currentUser.fullName = displayName
            currentUser.bio = bio
            if let username = username { currentUser.username = username }
            // isProfilePublic is now handled via updateProfilePrivacy call below.
            
            try await repo.saveUser(currentUser)
            
            // Explicitly saving privacy setting
            try await repo.updateProfilePrivacy(uid: uid, isPublic: isProfilePublic)
            
            // Optimization: Update local profile state immediately
            if var profile = currentUserProfile {
                profile = UserProfile(
                    id: profile.id,
                    displayName: displayName,
                    bio: bio,
                    avatarURL: profile.avatarURL,
                    isProfilePublic: isProfilePublic,
                    readReceiptsEnabled: readReceiptsEnabled,
                    postCount: profile.postCount,
                    followersCount: profile.followersCount,
                    followingCount: profile.followingCount,
                    eventCount: profile.eventCount,
                    joinCount: profile.joinCount,
                    friendCount: profile.friendCount,
                    username: username ?? profile.username,
                    city: profile.city,
                    interests: profile.interests,
                    shareCode11: profile.shareCode11
                )
                self.currentUserProfile = profile
            }
        } catch {
            print("❌ UserStore: Failed to update user profile: \(error)")
        }
    }
    
    /// Sets avatar URL locally (called after ProfileMediaService upload)
    func setAvatarURL(_ url: String) {
        currentUser.avatarURL = url
        if var profile = currentUserProfile {
            profile = UserProfile(
                id: profile.id,
                displayName: profile.displayName,
                bio: profile.bio,
                avatarURL: url,
                isProfilePublic: profile.isProfilePublic,
                readReceiptsEnabled: profile.readReceiptsEnabled,
                postCount: profile.postCount,
                followersCount: profile.followersCount,
                followingCount: profile.followingCount,
                eventCount: profile.eventCount,
                joinCount: profile.joinCount,
                friendCount: profile.friendCount,
                username: profile.username,
                city: profile.city,
                interests: profile.interests,
                shareCode11: profile.shareCode11
            )
            currentUserProfile = profile
        }
    }
    
    /// Loads the current user profile from Firestore (idempotent, single-flight).
    func loadCurrentUserProfile() async {
        guard !currentUser.id.isEmpty else { return }
        guard !isLoadingProfile else { return } // Prevent duplicate loads
        
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        
        do {
            guard let user = try await repo.fetchUser(id: currentUser.id) else { return }
            
            // Map User -> UserProfile
            self.currentUserProfile = UserProfile(
                id: user.id,
                displayName: user.fullName,
                bio: user.bio,
                avatarURL: user.avatarURL,
                isProfilePublic: user.isProfilePublic ?? true,
                readReceiptsEnabled: user.readReceiptsEnabled ?? true,
                postCount: 0,
                followersCount: 0,
                followingCount: 0,
                eventCount: 0,
                joinCount: 0,
                friendCount: 0,
                username: user.username,
                city: user.city,
                interests: user.interests ?? [],
                shareCode11: user.shareCode11
            )
            self.currentUser = user
            
            // Handle avatar URL cleanup
            if let avatarURL = user.avatarURL, avatarURL.hasPrefix("mock://") {
                 currentUser.avatarURL = nil
                 #if DEBUG
                 print("⚠️ UserStore: Cleaning mock:// avatar URL from Firestore")
                 // try? await repo.updateUser(uid: currentUser.id, data: ["avatarURL": FieldValue.delete()])
                 #endif
            }
        } catch {
            print("⚠️ UserStore.loadCurrentUserProfile: \(error)")
            // Profile might not exist yet, which is OK
        }
    }
    
    // MARK: - ShareCode
    
    /// Ensures user has a shareCode11 (generates if missing).
    func ensureShareCode() async -> String? {
        guard !currentUser.id.isEmpty else { return nil }
        
        // Check local first
        if let code = currentUser.shareCode11, !code.isEmpty {
            return code
        }
        
        do {
            let code = try await repo.ensureShareCode(uid: currentUser.id)
            currentUser.shareCode11 = code
            return code
        } catch {
            print("UserStore: ensureShareCode failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Profile Completion
    
    func completeProfile(fullName: String, username: String, city: String, bio: String?, interests: [String]) async {
        currentUser.fullName = fullName
        currentUser.username = username
        currentUser.city = city
        currentUser.bio = bio
        currentUser.interests = interests
        currentUser.profileCompleted = true
        
        // Save to remote
        do {
            try await repo.saveUser(currentUser)
            self.profileCompleteStorage = true
        } catch {
            print("UserStore: Failed to save profile: \(error)")
        }
    }
    
    func updateProfile(fullName: String, bio: String?, imageData: Data?) async {
        isLoading = true
        currentUser.fullName = fullName
        if let bio = bio { currentUser.bio = bio }
        if let imageData = imageData { currentUser.profileImageData = imageData }
        
        do {
            try await repo.saveUser(currentUser)
        } catch {
            print("UserStore: Failed to update profile: \(error)")
        }
        isLoading = false
    }
    
    func updateAvatar(assetName: String) {
        currentUser.avatarAssetName = assetName
    }
    
    func resetProfileCompletion() {
        profileCompleteStorage = false
        currentUser.username = nil
        currentUser.city = nil
    }
    
    // MARK: - Blocking
    
    @Published private(set) var blockedUserIds: Set<String> = []
    
    func fetchBlockedUsers() async {
        guard !currentUser.id.isEmpty else { return }
        do {
            let ids = try await repo.fetchBlockedUsers(uid: currentUser.id)
            self.blockedUserIds = ids
        } catch {
            print("UserStore: Failed to fetch blocked users: \(error)")
        }
    }
    
    func blockUser(_ userId: String) async {
        guard !currentUser.id.isEmpty else { return }
        blockedUserIds.insert(userId)
        try? await repo.blockUser(uid: currentUser.id, blockedUid: userId)
    }
    
    func unblockUser(_ userId: String) async {
        guard !currentUser.id.isEmpty else { return }
        blockedUserIds.remove(userId)
        try? await repo.unblockUser(uid: currentUser.id, blockedUid: userId)
    }
    
    // MARK: - Friends / Requests
    
    @Published private(set) var friendRequests: [FriendRequest] = []
    @Published private(set) var friends: [AppUser] = []
    
    private var requestListener: AnyObject?
    
    func listenFriendRequests() {
        guard !currentUser.id.isEmpty else { return }
        
        // Remove existing listener if any
        if let existing = requestListener {
           repo.removeListener(existing)
        }
        
        requestListener = repo.listenFriendRequests(uid: currentUser.id, onChange: { [weak self] reqs in
            Task { @MainActor in
                self?.friendRequests = reqs
            }
        }, onError: { error in
            print("⚠️ UserStore: request listener error: \(error)")
        })
    }
    
    func fetchFriends() async {
        guard !currentUser.id.isEmpty else { return }
        do {
            let list = try await repo.fetchFriends(uid: currentUser.id)
            self.friends = list
        } catch {
            print("⚠️ UserStore: fetchFriends error: \(error)")
        }
    }
    
    func sendFriendRequest(toUid: String) async {
        guard !currentUser.id.isEmpty else { return }
        do {
            try await repo.sendFriendRequest(fromUid: currentUser.id, toUid: toUid)
            print("✅ Friend request sent to \(toUid)")
        } catch {
            print("❌ Failed to send request: \(error)")
        }
    }
    
    func acceptFriendRequest(request: FriendRequest) async {
        guard !currentUser.id.isEmpty else { return }
        do {
            try await repo.acceptFriendRequest(requestId: request.id, fromUid: request.fromUid, toUid: request.toUid)
            // Refresh friends list
            await fetchFriends() 
        } catch {
            print("❌ Failed to accept request: \(error)")
        }
    }
    
    func rejectFriendRequest(request: FriendRequest) async {
        do {
            try await repo.rejectFriendRequest(requestId: request.id)
        } catch {
            print("❌ Failed to reject request: \(error)")
        }
    }
    
    func cancelFriendRequest(request: FriendRequest) async {
        do {
            try await repo.cancelFriendRequest(requestId: request.id)
        } catch {
            print("❌ Failed to cancel request: \(error)")
        }
    }
    
    func unfriend(friendUid: String) async {
        guard !currentUser.id.isEmpty else { return }
        do {
             try await repo.unfriend(uid: currentUser.id, friendUid: friendUid)
             await fetchFriends()
             
             // Optimistic update: Decrement friend count locally
             if currentUser.friends > 0 {
                 currentUser.friends -= 1
             }
             if var p = currentUserProfile {
                 p.friendCount = max(0, p.friendCount - 1)
                 currentUserProfile = p
             }
        } catch {
             print("❌ Failed to unfriend: \(error)")
        }
    }
    
    func getFriendStatus(uid: String) -> FriendStatus {
        if friends.contains(where: { $0.id == uid }) {
            return .friends
        }
        
        // Outgoing pending
        if let req = friendRequests.first(where: { req in
            req.fromUid == currentUser.id && req.toUid == uid && req.isPending
        }) {
            return .requestSent(req)
        }
        
        // Incoming pending
        if let req = friendRequests.first(where: { req in
            req.fromUid == uid && req.toUid == currentUser.id && req.isPending
        }) {
            return .requestReceived(req)
        }
        
        return .none
    }
    
    enum FriendStatus: Equatable {
        case none
        case friends
        case requestSent(FriendRequest)
        case requestReceived(FriendRequest)
    }
}

// MARK: - Save Post Logic

extension UserStore {
    /// Check if a post is saved locally
    func isPostSaved(_ postId: String) -> Bool {
        return savedPostIds.contains(postId)
    }

    /// Load saved post IDs from backend
    func loadSavedPostIds() async {
        guard !currentUser.id.isEmpty else { return }

        do {
            let ids = try await repo.fetchSavedPostIds(uid: currentUser.id)
            self.savedPostIds = Set(ids)
        } catch {
            print("❌ UserStore: Failed to load saved post IDs: \(error)")
        }
    }

    @MainActor
    func toggleSave(postId: String,
                    authorId: String? = nil,
                    caption: String? = nil,
                    mediaURL: String? = nil) async {

        // 1) Auth guard
        guard let uid = currentUser.id.isEmpty ? nil : currentUser.id else {
            print("❌ SAVE blocked: currentUser.id is nil/empty")
            self.lastSaveStatus = "BLOCKED: No UID"
            return
        }

        // Use local state for instant feedback
        let isSaved = savedPostIds.contains(postId)

        // Optimistic update
        if isSaved {
            savedPostIds.remove(postId)
        } else {
            savedPostIds.insert(postId)
        }

        do {
            if isSaved {
                try await repo.unsavePost(postId: postId, uid: uid)
                print("✅ UNSAVE success postId=\(postId) uid=\(uid)")
                self.lastSaveStatus = "UNSAVE OK"
            } else {
                try await repo.savePost(postId: postId, uid: uid)
                print("✅ SAVE success postId=\(postId) uid=\(uid)")
                self.lastSaveStatus = "SAVE OK"
            }
        } catch {
            // Rollback on error
            if isSaved {
                savedPostIds.insert(postId)
            } else {
                savedPostIds.remove(postId)
            }
            print("❌ SAVE/UNSAVE FAILED postId=\(postId) uid=\(uid) error=\(error)")
            self.lastSaveStatus = "FAILED: \(error.localizedDescription)"
        }
    }
}
