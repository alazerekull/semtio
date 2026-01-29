//
//  PublicProfileView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct PublicProfileView: View {
    let userId: String
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var chatStore: ChatStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var user: AppUser? // Mapped for UI
    @State private var profile: UserProfile? // Source of truth
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // Navigation
    @State private var chatThreadId: String?
    @State private var isChatPresented = false
    
    // Social stats
    @State private var postCount = 0
    @State private var followerCount = 0
    @State private var followingCount = 0
    
    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                if isLoading {
                    VStack {
                        ProgressView()
                            .padding(.top, 50)
                    }
                } else if let profile = profile, let user = user {
                    loadedProfileContent(profile: profile, user: user)
                } else {
                    errorView
                }
            }
        }
        .navigationTitle(profile?.username ?? user?.displayName ?? "Profil")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .navigationDestination(isPresented: $isChatPresented) {
            if let threadId = chatThreadId {
                ChatScreen(threadId: threadId)
            }
        }
    }
    
    @ViewBuilder
    private func loadedProfileContent(profile: UserProfile, user: AppUser) -> some View {
        VStack(spacing: 0) {
            
            // 1. Header (Read-only)
            // 1. Header (Read-only)
            ProfileHeaderView(
                user: user,
                eventCount: profile.eventCount + profile.joinCount,
                friendCount: profile.friendCount,
                postCount: profile.postCount,
                friendStatus: userStore.getFriendStatus(uid: userId),
                isFollowLoading: false, 
                isPremium: false,
                isBlocked: userStore.blockedUserIds.contains(userId),
                onEditTapped: nil,
                onSettingsTapped: nil,
                onAddFriend: {
                    Task { await friendStore.sendRequest(from: userStore.currentUser.id, to: userId) }
                },
                onCancelRequest: {
                    if case .requestSent(let req) = userStore.getFriendStatus(uid: userId) {
                        Task { await friendStore.cancelRequest(requestId: req.id) }
                    }
                },
                onAcceptRequest: {
                    if case .requestReceived(let req) = userStore.getFriendStatus(uid: userId) {
                        Task { await friendStore.accept(request: req) }
                    }
                },
                onRejectRequest: {
                    if case .requestReceived(let req) = userStore.getFriendStatus(uid: userId) {
                        Task { await friendStore.reject(request: req) }
                    }
                },
                onUnfriend: {
                     // Optimistic UI update
                     Task { 
                        await userStore.unfriend(friendUid: userId)
                        // Update local view state
                        if var p = self.profile {
                             p.friendCount = max(0, p.friendCount - 1)
                             self.profile = p
                        }
                     }
                },
                onMessage: {
                    Task {
                        if let threadId = await chatStore.createDM(with: userId, currentUserId: userStore.currentUser.id) {
                            self.chatThreadId = threadId
                            self.isChatPresented = true
                        }
                    }
                },
                onFollowTapped: nil
            )
            
            Divider()
                .padding(.vertical, 8)
            
            // 2. Content
            if profile.isProfilePublic || userId == userStore.currentUser.id || appState.followInteractions.isFollowing(userId) {
                // Show Content
                ProfilePostsGridView(userId: userId, repo: appState.posts)
            } else {
                // Private Profile State
                privateProfileView
            }
            
            Spacer()
        }
    }
    
    private var privateProfileView: some View {
        VStack(spacing: Spacing.md) {
            Spacer().frame(height: 40)
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundColor(AppColor.textSecondary)
            Text("Bu Hesap Gizli")
                .font(AppFont.subheadline)
                .foregroundColor(AppColor.textPrimary)
            Text("Fotoğraf ve videolarını görmek için bu hesabı takip et.")
                .font(AppFont.caption)
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
            Spacer()
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.slash")
                .font(.system(size: 48))
                .foregroundColor(AppColor.textSecondary)
            Text("Kullanıcı bulunamadı")
                .font(AppFont.bodyBold)
                .foregroundColor(AppColor.textSecondary)
            
            if let error = errorMessage {
                Text(error)
                    .font(AppFont.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.top, 50)
    }
    
    private func loadData() async {
        isLoading = true
        print("🔍 PublicProfileView: Loading data to userId: \(userId)")
        
        do {
            // Fetch Profile
            // Fetch Profile (User)
            guard let fetchedUser = try await userStore.repo.fetchUser(id: userId) else {
                errorMessage = "Kullanıcı bulunamadı."
                isLoading = false
                return
            }
            
            // Map User -> UserProfile
            self.profile = UserProfile(
                id: fetchedUser.id,
                displayName: fetchedUser.fullName,
                bio: fetchedUser.bio,
                avatarURL: fetchedUser.avatarURL,
                isProfilePublic: true, // TODO: Add to User model
                postCount: 0,
                followersCount: 0,
                followingCount: 0,
                eventCount: 0,
                joinCount: 0,
                friendCount: fetchedUser.friends,
                username: fetchedUser.username == nil || fetchedUser.username?.isEmpty == true ? nil : fetchedUser.username,
                city: fetchedUser.city,
                interests: fetchedUser.interests ?? []
            )
            
            // Map to AppUser for Header Compatibility
            self.user = fetchedUser
            
            // Load Interactions
            await appState.followInteractions.checkFollowStatus(userId: userId)
            
            // Force refresh friend status
            if !userStore.currentUser.id.isEmpty {
                print("🔄 PublicProfileView: Fetching friends for \(userStore.currentUser.id)... current status: \(userStore.getFriendStatus(uid: userId))")
                await userStore.fetchFriends()
                print("✅ PublicProfileView: Friends fetched. New status: \(userStore.getFriendStatus(uid: userId))")
            }
            
        } catch {
            print("PublicProfileView: Error loading logic: \(error)")
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
