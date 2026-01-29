//
//  ProfileTabsView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Modern profile tabs with animated indicator, haptic feedback, and smooth transitions

import SwiftUI

struct ProfileTabsView: View {
    @Binding var selectedTab: ProfileViewModel.ProfileTab
    @Binding var selectedSavedTab: ProfileViewModel.SavedTab
    let events: [Event]

    var createdEvents: [Event] = []
    var joinedEvents: [Event] = []
    var isEventsLoading: Bool = false
    var onEventTap: ((Event) -> Void)? = nil
    var onCreateTapped: (() -> Void)? = nil

    @EnvironmentObject var appState: AppState
    @Namespace private var tabNamespace
    @State private var tabTransition: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab Selector - Always visible
            tabSelector

            // Content with smooth transition
            tabContent
                .animation(.easeInOut(duration: 0.25), value: selectedTab)
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        VStack(spacing: 0) {
            // Modern Tab Bar with clean separation
            HStack(spacing: 0) {
                ProfileTabButton(
                    icon: "square.grid.3x3.fill",
                    label: "", // Icon only
                    isSelected: selectedTab == .posts,
                    namespace: tabNamespace
                ) {
                    switchTab(to: .posts)
                }
                .frame(maxWidth: .infinity)

                ProfileTabButton(
                    icon: "play.rectangle.fill",
                    label: "",
                    isSelected: selectedTab == .created,
                    namespace: tabNamespace
                ) {
                    switchTab(to: .created)
                }
                .frame(maxWidth: .infinity)

                ProfileTabButton(
                    icon: "bookmark.fill", 
                    label: "",
                    isSelected: selectedTab == .joined,
                    namespace: tabNamespace
                ) {
                    switchTab(to: .joined)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, Spacing.sm)
            .background(AppColor.background)
            
            // Thin separator line
            Divider()
                .background(AppColor.border.opacity(0.2))
        }
        .background(AppColor.background)
    }

    private func switchTab(to tab: ProfileViewModel.ProfileTab) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            selectedTab = tab
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .posts:
            ProfilePostsGridView(userId: appState.auth.uid ?? "", repo: appState.posts)
                .padding(.top, Spacing.sm)

        case .created:
            ProfileEventsModuleView(
                createdEvents: createdEvents,
                joinedEvents: joinedEvents,
                isLoading: isEventsLoading,
                onEventTap: { event in
                    onEventTap?(event)
                },
                onCreateTapped: onCreateTapped
            )
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)

        case .joined:
            ProfileSavedContentView(
                selectedTab: $selectedSavedTab,
                onEventTap: { event in
                    onEventTap?(event)
                }
            )
            .padding(.top, Spacing.md)
        }
    }
}

private struct ProfileTabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Icon area with enhanced visual feedback
                ZStack {
                    Image(systemName: icon)
                        .font(AppFont.title2)
                        .foregroundColor(isSelected ? AppColor.textPrimary : AppColor.textMuted)
                        .symbolEffect(.bounce, value: isSelected)
                }
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                
                // Animated underline with smooth transition
                ZStack {
                    // Always present container for consistent spacing
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 1)
                    
                    // Active indicator
                    if isSelected {
                        Rectangle()
                            .fill(AppColor.textPrimary)
                            .frame(height: 1)
                            .matchedGeometryEffect(id: "activeTab", in: namespace)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

// MARK: - Saved Content View

struct ProfileSavedContentView: View {
    @Binding var selectedTab: ProfileViewModel.SavedTab

    var onEventTap: ((Event) -> Void)? = nil

    @EnvironmentObject var appState: AppState
    @State private var savedEvents: [Event] = []
    @State private var savedPosts: [Post] = []
    @State private var isLoading = false

    typealias SavedTab = ProfileViewModel.SavedTab

    private let gridColumns = [
        GridItem(.flexible(), spacing: 1.5),
        GridItem(.flexible(), spacing: 1.5),
        GridItem(.flexible(), spacing: 1.5)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Segmented Tab Selector
            HStack(spacing: 0) {
                ForEach(SavedTab.allCases, id: \.self) { tab in
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 6) {
                            HStack(spacing: 5) {
                                Image(systemName: tab.icon)
                                    .font(AppFont.footnote)
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium))
                            }
                            .foregroundColor(selectedTab == tab ? AppColor.textPrimary : AppColor.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)

                            // Underline indicator
                            Rectangle()
                                .fill(selectedTab == tab ? AppColor.textPrimary : Color.clear)
                                .frame(height: 1.5)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, Spacing.md)

            Divider()
                .padding(.bottom, Spacing.sm)

            // Content
            if isLoading {
                VStack(spacing: 12) {
                    Spacer().frame(height: 60)
                    ProgressView()
                        .tint(AppColor.textMuted)
                }
            } else {
                switch selectedTab {
                case .events:
                    if savedEvents.isEmpty {
                        savedEmptyView(
                            icon: "bookmark",
                            title: "Kayıtlı etkinlik yok",
                            subtitle: "Etkinlikleri kaydettiğinde burada görünür."
                        )
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 1.5) {
                            ForEach(savedEvents) { event in
                                Button {
                                    onEventTap?(event)
                                } label: {
                                    ProfileEventGridItem(event: event)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, 1.5)
                    }

                case .posts:
                    if savedPosts.isEmpty {
                        savedEmptyView(
                            icon: "bookmark",
                            title: "Kayıtlı gönderi yok",
                            subtitle: "Gönderileri kaydettiğinde burada görünür."
                        )
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 1.5) {
                            ForEach(savedPosts) { post in
                                Button {
                                    appState.handleDeepLink(URL(string: "semtio://post/\(post.id)")!)
                                } label: {
                                    PostThumbnailView(post: post)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                        .padding(.horizontal, 1.5)
                    }
                }
            }

            Spacer(minLength: 50)
        }
        .task {
            await loadSavedContent()
        }
        .onChange(of: appState.lastDeletedPostId) { _, postId in
            if let postId = postId {
                savedPosts.removeAll { $0.id == postId }
            }
        }
        .onChange(of: appState.savedPostsChanged) { _, _ in
            Task {
                await loadSavedContent()
            }
        }
    }

    private func savedEmptyView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 50)

            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundColor(AppColor.textMuted.opacity(0.6))

            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(AppColor.textPrimary)

            Text(subtitle)
                .font(AppFont.footnote)
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }

    private func loadSavedContent() async {
        guard let uid = appState.auth.uid else {
            isLoading = false
            return
        }

        isLoading = true
        do {
            async let postsTask = appState.posts.fetchSavedPosts(userId: uid)
            async let eventsTask = appState.events.fetchSavedEvents(userId: uid)
            savedPosts = try await postsTask
            savedEvents = try await eventsTask
        } catch {
            print("❌ ProfileSavedContentView: Failed to load saved content: \(error)")
        }
        isLoading = false
    }
}


// MARK: - Grid Item

struct ProfileEventGridItem: View {
    let event: Event

    @State private var isAppeared = false

    var body: some View {
        ZStack {
            // Background gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [categoryColor, categoryColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Content
            VStack(spacing: 6) {
                Image(systemName: event.category.icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(AppColor.onPrimary)

                Text(event.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(AppColor.onPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
            }

            // Live badge
            if event.isActive {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(AppColor.success)
                                .frame(width: 6, height: 6)
                            Text("Canlı")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(AppColor.onPrimary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        .padding(4)
                    }
                    Spacer()
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .scaleEffect(isAppeared ? 1.0 : 0.9)
        .opacity(isAppeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isAppeared = true
            }
        }
    }

    private var categoryColor: Color {
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

// MARK: - Tab Extension

extension ProfileViewModel.ProfileTab {
    var icon: String {
        switch self {
        case .posts: return "square.grid.3x3.fill"
        case .created: return "calendar"
        case .joined: return "bookmark.fill"
        }
    }
}

// Legacy compatibility
private struct AnimatedTabButton: View {
    let icon: String
    let isSelected: Bool
    var namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        ProfileTabButton(icon: icon, label: "", isSelected: isSelected, namespace: namespace, action: action)
    }
}

#Preview {
    ProfileTabsView(
        selectedTab: .constant(.created),
        selectedSavedTab: .constant(.events),
        events: []
    )
}
