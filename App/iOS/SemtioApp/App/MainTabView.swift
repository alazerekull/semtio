//
//  MainTabView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var deepLinkService: DeepLinkService
    @EnvironmentObject var eventStore: EventStore
    
    @State private var homeScrollToTop = false
    @State private var tabBarHeight: CGFloat = 0

    // Deep Link Sheet States
    @State private var showingDeepLinkEvent: Event? = nil
    @State private var showingDeepLinkPostId: IdentifiableString? = nil
    @State private var showingPublicProfileId: IdentifiableString? = nil
    
    struct IdentifiableString: Identifiable {
        let id: String
        var ownerId: String? = nil
        var username: String? = nil
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.semtioBackground.ignoresSafeArea()
            
            // Main Content
            Group {
                switch appState.selectedTab {
                case .home:
                    HomeView()
                        // Removed .id(homeId) - was causing complete view recreation
                case .events:
                    EventsScreenV2(userStore: appState.userStore)
                case .map:
                    MapScreen()
                case .chat:
                    MessagesInboxView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Floating Tab Bar
            if !appState.isTabBarHidden {
                CustomTabBar(selectedTab: $appState.selectedTab)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: TabBarHeightPreferenceKey.self, value: proxy.size.height)
                        }
                    )
                    .zIndex(1)
                    .transition(.move(edge: .bottom))
            }
        }
        .ignoresSafeArea(.keyboard)
        .onPreferenceChange(TabBarHeightPreferenceKey.self) { height in
            self.tabBarHeight = height
            print("📏 Tab Bar Height Measured: \(height)")
        }
        .environment(\.tabBarHeight, tabBarHeight)
        .sheet(item: $showingDeepLinkEvent) { event in
            NavigationStack {
                EventDetailScreen(event: event)
            }
        }
        .sheet(item: $showingDeepLinkPostId) { wrapper in
            NavigationStack {
                PostDetailScreen(postId: wrapper.id, ownerId: wrapper.ownerId, username: wrapper.username)
            }
        }
        .sheet(item: $showingPublicProfileId) { wrapper in
            PublicProfileView(userId: wrapper.id)
        }
        // Deep Link Listeners
        .onChange(of: appState.deepLinkEventId) { _, newValue in
            if let eventId = newValue {
                Task {
                    if let event = try? await appState.events.fetchEvent(eventId: eventId) {
                        showingDeepLinkEvent = event
                    }
                    appState.clearDeepLinkEvent()
                }
            }
        }
        .onChange(of: appState.deepLinkPostId) { _, newValue in
            if let postId = newValue {
                showingDeepLinkPostId = IdentifiableString(id: postId, ownerId: appState.deepLinkPostOwnerId, username: appState.deepLinkPostUsername)
                appState.clearDeepLinkPost()
            }
        }
        .onChange(of: appState.publicProfileUserId) { _, newValue in
            if let userId = newValue {
                showingPublicProfileId = IdentifiableString(id: userId)
                // We don't clear publicProfileUserId immediately because it acts as state, 
                // but for sheet presentation it's better to reset in AppState or here.
                // AppState property is publicProfileUserId, assume it can be set to nil
            }
        }
        .onChange(of: showingPublicProfileId?.id) { _, newValue in
            if newValue == nil {
                appState.publicProfileUserId = nil
            }
        }
        // Removed: ResetTab notification handler that was recreating HomeView
    }
}
