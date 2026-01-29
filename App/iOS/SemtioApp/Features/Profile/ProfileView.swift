//
//  ProfileView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Modern profile with pull-to-refresh, smooth animations, and refined layout

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var eventStore: EventStore
    @StateObject private var viewModel: ProfileViewModel

    @State private var showEditProfile = false
    @State private var showFriends = false
    @State private var showSettings = false
    @State private var showCreateEvent = false
    @State private var showCreatePost = false
    @State private var selectedEventForDetail: Event?
    @State private var scrollOffset: CGFloat = 0
    @State private var isRefreshing = false

    init() {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(
            eventRepo: FirestoreEventRepository(),
            friendRepo: FirestoreFriendRepository(),
            postRepo: FirestorePostRepository(),
            userId: ""
        ))
    }

    private var friendCount: Int {
        friendStore.friends.count
    }

    var body: some View {
        NavigationStack {
            profileContent
                .refreshable {
                    await loadProfileData()
                }
                .background(AppColor.background)
                .navigationTitle(userStore.currentUser.username ?? "Profil")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    toolbarContent
                }
                .navigationDestination(isPresented: $showSettings) {
                    SettingsView()
                }
                .navigationDestination(isPresented: $showFriends) {
                    FriendsView(initialTab: FriendsView.tabRequests)
                }
                .sheet(item: $selectedEventForDetail) { event in
                    NavigationStack {
                        EventDetailScreen(event: event)
                    }
                }
                .sheet(isPresented: $showCreateEvent) {
                    NavigationStack {
                        CreateEventView()
                    }
                }
        }
        .task {
            await loadProfileData()
        }
        .onChange(of: appState.lastDeletedPostId) { _, _ in
            viewModel.decrementPostCount()
        }
        .onChange(of: appState.postsChanged) { _, changed in
            if changed {
                viewModel.incrementPostCount()
            }
        }
        .onChange(of: appState.profileTabToSelect) { _, tab in
            if let tab = tab {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    viewModel.selectedTab = tab
                }
                appState.profileTabToSelect = nil
            }
        }
        .onChange(of: appState.savedTabToSelect) { _, tab in
            if let tab = tab {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    viewModel.selectedSavedTab = tab
                }
                appState.savedTabToSelect = nil
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showCreatePost, onDismiss: {
            Task {
                await viewModel.loadProfileData()
            }
        }) {
             CreatePostScreen()
        }
    }

    private var profileContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Profile Header
                ProfileHeaderView(
                    user: userStore.currentUser,
                    eventCount: viewModel.createdEvents.count + viewModel.joinedEvents.count,
                    friendCount: friendCount,
                    postCount: viewModel.postCount,
                    // Self Profile -> status .none (actions hidden) or could add specific "Share Profile"
                    friendStatus: .none, 
                    isFollowLoading: false,
                    isPremium: appState.subscription.isPremium,
                    isBlocked: false,
                    onEditTapped: { showEditProfile = true },
                    onSettingsTapped: { showSettings = true },
                    onAddFriend: nil,
                    onCancelRequest: nil,
                    onAcceptRequest: nil,
                    onRejectRequest: nil,
                    onUnfriend: nil,
                    onMessage: nil,
                    onFollowTapped: nil
                )

                // Content Tabs
                ProfileTabsView(
                    selectedTab: $viewModel.selectedTab,
                    selectedSavedTab: $viewModel.selectedSavedTab,
                    events: viewModel.currentTabEvents,
                    createdEvents: viewModel.createdEvents,
                    joinedEvents: viewModel.joinedEvents,
                    isEventsLoading: viewModel.isLoading,
                    onEventTap: { event in
                        selectedEventForDetail = event
                    },
                    onCreateTapped: {
                        showCreateEvent = true
                    }
                )

                Spacer().frame(height: 100)
            }
        }
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
             HStack(spacing: 16) {
                 Button {
                     showCreatePost = true
                 } label: {
                     Image(systemName: "plus.app")
                         .font(AppFont.title2)
                         .foregroundColor(AppColor.textPrimary)
                 }

                 Button {
                     showFriends = true
                 } label: {
                     // "arkadaşlar kısmı... instagram mantığı" -> Heart icon
                     Image(systemName: "heart")
                         .font(AppFont.title2)
                         .foregroundColor(AppColor.textPrimary)
                 }
             }
        }
    }


    private func loadProfileData() async {
        await userStore.loadCurrentUserProfile()

        guard let uid = appState.auth.uid, !uid.isEmpty else {
            return
        }

        await friendStore.loadFriends(userId: uid)

        viewModel.setUserId(uid)
        await viewModel.loadProfileData()

        checkPendingNavigation()
    }

    @MainActor
    private func checkPendingNavigation() {
        if let tab = appState.profileTabToSelect {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                viewModel.selectedTab = tab
            }
            appState.profileTabToSelect = nil
        }

        if let savedTab = appState.savedTabToSelect {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                viewModel.selectedSavedTab = savedTab
            }
            appState.savedTabToSelect = nil
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environmentObject(UserStore(repo: MockUserRepository()))
        .environmentObject(AppState(
            session: SessionManager(),
            theme: AppThemeManager(),
            location: LocationManager()
        ))
}
