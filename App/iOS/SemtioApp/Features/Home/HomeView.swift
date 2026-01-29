//
//  HomeView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Instagram-style event feed with FeedStore integration.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userStore: UserStore
    
    // Unified Feed ViewModel
    // Ideally injected via factory, but instantiating here for simplicity in this migration
    @StateObject private var feedViewModel = FeedViewModel(repo: FirestoreFeedRepository())

    // Announcement state
    @State private var currentAnnouncement: Announcement?
    @State private var isLoadingAnnouncement = true

    // Navigation state
    @State private var activeSheet: HomeSheet?
    @State private var showingUploadPost = false
    @State private var showingStoryCamera = false // New state
    
    enum HomeSheet: Identifiable {
        case notifications
        case storyCamera // New enum case
        
        var id: Int { hashValue }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ... (Content remains)
                    // Compact Announcement Banner
                    if let announcement = currentAnnouncement {
                        CompactAnnouncementBanner(announcement: announcement)
                            .padding(.horizontal, Spacing.md)
                            .padding(.top, Spacing.md)
                            .padding(.bottom, Spacing.sm)
                    }
                    
                    // SEGMENTED CONTROL for Feed
                    Picker("Feed", selection: $feedViewModel.currentFilter) {
                        Text("Takip Ettiklerim").tag(PostFeedStore.FeedFilter.following)
                        Text("Keşfet").tag(PostFeedStore.FeedFilter.recent)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .onChange(of: feedViewModel.currentFilter) { _, newValue in
                        Task { await feedViewModel.setFilter(newValue) }
                    }
                    
                    // Event Stories Row (Instagram-style)
                    if feedViewModel.currentFilter == .following {
                         StoryBarView()
                    }
                    
                    Divider()
                        .padding(.vertical, Spacing.sm)
                    
                    // Error State (For Debugging)
                    if let error = feedViewModel.errorMessage {
                        VStack(spacing: 8) {
                            Text("Hata Oluştu")
                                .font(AppFont.captionBold)
                                .foregroundColor(AppColor.error)
                            Text(error)
                                .font(AppFont.caption)
                                .foregroundColor(AppColor.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(AppColor.error.opacity(0.1))
                        .cornerRadius(8)
                        .padding()
                    }

                    // Unified Feed Content
                    LazyVStack(spacing: 0) {
                        ForEach(feedViewModel.items) { item in
                            FeedCardView(item: item)
                                .onAppear {
                                    // Pagination Trigger
                                    if item.id == feedViewModel.items.last?.id && feedViewModel.hasMore {
                                        Task { await feedViewModel.fetchMore() }
                                    }
                                }
                            
                            // Separator
                            Divider()
                                .padding(.vertical, Spacing.sm)
                        }
                        
                        if feedViewModel.isLoading {
                            LoadingStateView(message: "Icerikler yukleniyor...")
                                .frame(height: 100)
                        } else if feedViewModel.items.isEmpty && !feedViewModel.isLoading {
                            // Different empty states for different filters
                            if feedViewModel.currentFilter == .following {
                                FollowingEmptyStateView()
                            } else {
                                EmptyStateView(
                                    iconName: "photo.stack",
                                    title: "Henuz Icerik Yok",
                                    subtitle: "Yeni paylasimlari gormek icin daha sonra tekrar gel."
                                )
                                .padding(.top, Spacing.xl)
                            }
                        }
                    }
                }
            }
            .background(AppColor.background)
            .refreshable {
                await refreshAll()
            }
            .navigationTitle("Sizin İçin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        activeSheet = .storyCamera
                    }) {
                        Image(systemName: "camera")
                            .font(AppFont.title2)
                            .foregroundColor(AppColor.textPrimary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: Spacing.sm) {
                        // Notifications Button
                        Button(action: {
                            activeSheet = .notifications
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "heart")
                                    .font(AppFont.title2)
                                    .foregroundColor(AppColor.textPrimary)

                                // Unread badge
                                if appState.notifications.hasUnread {
                                    Circle()
                                        .fill(AppColor.error)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 2, y: -2)
                                }
                            }
                        }

                        // Search/Discover Button
                        NavigationLink(destination: FriendSearchScreen()) {
                            Image(systemName: "magnifyingglass")
                            .font(AppFont.title2)
                            .foregroundColor(AppColor.textPrimary)
                        }
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .notifications:
                    NotificationsView()
                        .environmentObject(appState)
                case .storyCamera:
                    StoryCreationSheet()
                }
            }
            // Swipe Right Gesture
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width > 100 && abs(value.translation.height) < 50 {
                            activeSheet = .storyCamera
                        }
                    }
            )
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        // Load announcement
        isLoadingAnnouncement = true
        currentAnnouncement = try? await appState.announcementRepo.fetchLatestAnnouncement()
        isLoadingAnnouncement = false

        // Load unified feed
        // 1. Fetch friends to populate "following" filter
        await appState.friends.loadFriends(userId: userStore.currentUser.id)
        let friendIds = appState.friends.friends.map { $0.id }
        // Ensure current user is not in following (though logic filters by authorIds)
        // Add self to see own posts in feed? Usually yes for "following" feed or separate logic.
        // For now, friends + self
        if friendIds.isEmpty {
            // No friends yet: Show Global/Recent feed (Fallback)
            feedViewModel.updateFollowingIds([])
        } else {
            // Has friends: Show Friends + Self
            var feedIds = friendIds
            feedIds.append(userStore.currentUser.id)
            feedViewModel.updateFollowingIds(feedIds)
        }
        
        await feedViewModel.fetchInitial()
        
        // Load events for stories (still needed for the top row?)
        if appState.feed.feedEvents.isEmpty {
             await appState.feed.loadInitialFeed()
        }

        // Load notification count
        await appState.notifications.refreshUnreadCount()
    }
    
    private func refreshAll() async {
        await feedViewModel.refresh()
        await appState.notifications.refreshUnreadCount()
        // Refresh stories too
        await appState.feed.refresh()
    }
}

// MARK: - Extensions

extension PostFeedStore.FeedFilter: CustomStringConvertible {
    var description: String {
        switch self {
        case .following: return "Takip Ettiklerim"
        case .recent: return "En Yeni"
        }
    }
}

// MARK: - Compact Announcement Banner

// MARK: - Companion Subviews

struct CompactAnnouncementBanner: View {
    let announcement: Announcement
    
    var body: some View {
        NavigationLink(destination: AnnouncementDetailScreen(announcement: announcement)) {
            HStack(spacing: Spacing.md) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppColor.onPrimary)
                
                Text(announcement.title)
                    .font(AppFont.captionBold)
                    .foregroundColor(AppColor.onPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(AppFont.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                LinearGradient(
                    colors: [AppColor.primary, AppColor.accent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(Radius.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Suggested Users Section

struct SuggestedUsersSection: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userStore: UserStore
    @State private var suggestedUsers: [AppUser] = []
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Önerilen Kişiler")
                    .font(AppFont.subheadline)
                    .foregroundColor(AppColor.textPrimary)
                Spacer()
                NavigationLink(destination: FriendSearchScreen()) {
                    Text("Tümünü Gör")
                         .font(AppFont.captionBold)
                        .foregroundColor(AppColor.primary)
                }
            }
            .padding(.horizontal, Spacing.md)

            if isLoading {
               LoadingStateView()
                .frame(height: 120)
            } else if suggestedUsers.isEmpty {
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        ForEach(suggestedUsers.prefix(10)) { user in
                            SuggestedUserCard(user: user)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
        }
        .padding(.top, Spacing.md)
        .task {
            await loadSuggestedUsers()
        }
    }

    private func loadSuggestedUsers() async {
        isLoading = true
        do {
            suggestedUsers = try await userStore.fetchSuggestedUsers(limit: 10)
        } catch {
            print("Failed to load suggested users: \(error)")
        }
        isLoading = false
    }
}

struct SuggestedUserCard: View {
    let user: AppUser
    @State private var isFollowing = false

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Avatar (using DS Component size if applicable, or custom for this card)
            ProfileAvatarSmall(user: user, size: 60)

            // Name
            Text(user.fullName)
                .font(AppFont.captionBold)
                .foregroundColor(AppColor.textPrimary)
                .lineLimit(1)

            // Follow button
            Button {
                Task {
                    isFollowing.toggle()
                    // TODO: Actually follow
                }
            } label: {
                Text(isFollowing ? "Takip" : "Takip Et")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isFollowing ? AppColor.textPrimary : AppColor.onPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 6)
                    .background(isFollowing ? AppColor.surface : AppColor.primary)
                    .cornerRadius(Radius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .stroke(isFollowing ? AppColor.border : Color.clear, lineWidth: 1)
                    )
            }
        }
        .frame(width: 110)
        .padding(.vertical, Spacing.md)
        .background(AppColor.surface)
        .cornerRadius(Radius.md)
        .semtioShadow(.card)
    }
}

struct ProfileAvatarSmall: View {
    let user: AppUser
    var size: CGFloat = 50

    var body: some View {
        Group {
            if let avatarURL = user.avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialsFallback
                    }
                }
            } else {
                initialsFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(AppColor.primaryFallback.opacity(0.3), lineWidth: 2)
        )
    }

    private var initialsFallback: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [AppColor.primaryFallback, Color.purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(String(user.fullName.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(AppColor.onPrimary)
            )
    }
}

// MARK: - Trending Events Section

struct TrendingEventsSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if !appState.feed.feedEvents.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Popüler Etkinlikler")
                        .font(AppFont.headline)
                        .foregroundColor(AppColor.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, Spacing.md)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        ForEach(appState.feed.feedEvents.prefix(8)) { event in
                            NavigationLink(destination: EventDetailScreen(event: event)) {
                                TrendingEventCard(event: event)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
            .padding(.top, Spacing.lg)
        }
    }
}

struct TrendingEventCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover
            ZStack(alignment: .bottomLeading) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [categoryColor, categoryColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 80)

                // Category icon
                Image(systemName: event.category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Category badge
                Text(event.category.localizedName)
                    .font(AppFont.captionBold)
                    .foregroundColor(AppColor.onPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(Radius.sm)
                    .padding(8)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(AppFont.captionBold)
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)

                Text(event.dayLabel)
                    .font(AppFont.caption)
                    .foregroundColor(AppColor.textSecondary)

                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text("\(event.participantCount)")
                        .font(AppFont.caption)
                }
                .foregroundColor(AppColor.textSecondary)
            }
            .padding(Spacing.sm)
        }
        .frame(width: 140)
        .background(AppColor.surface)
        .cornerRadius(Radius.md)
        .semtioShadow(.card)
    }

    private var categoryColor: Color {
        // Simple fallback mapping, logic could be moved to Event extensions
        switch event.category {
        case .party: return .purple
        case .sport: return .orange
        case .music: return .pink
        case .food: return .red
        case .meetup: return .blue
        case .other: return .gray
        }
    }
}

// MARK: - Following Empty State View

struct FollowingEmptyStateView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColor.primaryFallback.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 44))
                    .foregroundColor(AppColor.primaryFallback)
            }

            VStack(spacing: Spacing.sm) {
                Text("Takip Ettigin Kimse Yok")
                    .font(AppFont.title3)
                    .foregroundColor(AppColor.textPrimary)

                Text("Arkadaslarini takip etmeye basla ve paylarimlarini gor.")
                    .font(AppFont.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            NavigationLink(destination: FriendSearchScreen()) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                    Text("Arkadas Bul")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(AppColor.primary)
                .cornerRadius(28)
                .shadow(color: AppColor.primary.opacity(0.4), radius: 12, x: 0, y: 6)
            }

            Spacer()
        }
        .padding(.top, Spacing.xl)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(UserStore(repo: MockUserRepository()))
        .environmentObject(AppState(
            session: SessionManager(),
            theme: AppThemeManager(),
            location: LocationManager()
        ))
}
