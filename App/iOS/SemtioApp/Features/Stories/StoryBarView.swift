//
//  StoryBarView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct StoryBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var chatStore: ChatStore
    @EnvironmentObject var eventStore: EventStore
    
    // Presentation State
    @State private var showCreation = false

    @State private var showMyStory = false
    @State private var selectedBundle: StoryStore.UserStoryBundle? // Typed state

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                
                // 1. My Story
                MyStoryBubble(showCreation: $showCreation, showMyStory: $showMyStory)
                
                // 2. Friends Stories
                ForEach(appState.stories.storyBundles) { bundle in
                    Button {
                        selectedBundle = bundle
                    } label: {
                        StoryCircle(bundle: bundle)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .sheet(isPresented: $showCreation, onDismiss: {
            Task { await appState.stories.refresh() }
        }) {
            StoryCreationSheet()
                .environmentObject(appState)
                .environmentObject(userStore)
                .environmentObject(chatStore)
                .environmentObject(eventStore)
                .environmentObject(appState.stories)
        }
        .fullScreenCover(isPresented: $showMyStory) {
            let user = userStore.currentUser
            let myBundle = StoryStore.UserStoryBundle(user: user, stories: appState.stories.myStories)
            StoryViewerScreen(bundle: myBundle)
                .environmentObject(appState)
                .environmentObject(userStore)
                .environmentObject(chatStore)
                .environmentObject(eventStore)
                .environmentObject(appState.stories)
        }
        .fullScreenCover(item: $selectedBundle) { bundle in
            StoryViewerScreen(bundle: bundle)
                .environmentObject(appState)
                .environmentObject(userStore)
                .environmentObject(chatStore)
                .environmentObject(eventStore)
                .environmentObject(appState.stories)
        }
        .task {
            if appState.stories.storyBundles.isEmpty {
                await appState.stories.refresh()
            }
        }
    }
}

// MARK: - Subviews

struct MyStoryBubble: View {
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var appState: AppState
    @Binding var showCreation: Bool
    @Binding var showMyStory: Bool
    
    var hasActiveStory: Bool {
        !appState.stories.myStories.isEmpty
    }
    
    var body: some View {

        VStack(spacing: 6) {
            ZStack(alignment: .center) {
                // Ring (if active)
                if hasActiveStory {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.blue, .purple, .orange, .pink, .red, .yellow], // Instagram-ish active
                                startPoint: .bottomLeading,
                                endPoint: .topTrailing
                            ),
                            lineWidth: 3.0 // Thicker ring
                        )
                        .frame(width: 78, height: 78)
                } else {
                     // Placeholder to keep spacing consistent
                    Circle()
                        .strokeBorder(Color.clear, lineWidth: 3.0)
                        .frame(width: 78, height: 78)
                }
                
                // Avatar
                StoryAvatar(url: userStore.currentUser.avatarURL, size: 68) // Slightly larger avatar
            }
            .overlay(alignment: .bottomTrailing) {
                // Plus Badge (Only if NO active story)
                if !hasActiveStory {
                    ZStack {
                        Circle()
                            .fill(Color.blue) // Instagram Blue
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle().stroke(AppColor.background, lineWidth: 3) // Cutout gap
                            )
                        
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 2, y: 2) // Slight offset optimization
                }
            }
            .frame(width: 78, height: 78) // Consistent container
            .onTapGesture {
                if hasActiveStory {
                    showMyStory = true
                } else {
                    showCreation = true
                }
            }
            .onLongPressGesture {
                showCreation = true
            }
            
            Text("Hikayen")
                .font(.system(size: 11))
                .foregroundColor(AppColor.textSecondary)
        }
    }
}

struct StoryCircle: View {
    let bundle: StoryStore.UserStoryBundle
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .center) {
                // Ring
                if bundle.hasUnseen {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.yellow, .orange, .red, .pink, .purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3.0
                        )
                        .frame(width: 78, height: 78)
                } else {
                    Circle()
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 78, height: 78)
                }
                
                // Avatar
                StoryAvatar(url: bundle.user.avatarURL, size: 68)
            }
            
            Text(bundle.user.username ?? bundle.user.fullName)
                .font(.system(size: 11))
                .foregroundColor(AppColor.textPrimary)
                .lineLimit(1)
                .frame(width: 74)
        }
    }
}

// Local Avatar component to ensure availability
struct StoryAvatar: View {
    let url: String?
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.1))
            .frame(width: size, height: size)
            .overlay(
                Group {
                    if let str = url, let u = URL(string: str) {
                        AsyncImage(url: u) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: size, height: size, alignment: .center)
                            case .failure:
                                Image(systemName: "person.fill")
                                    .font(.system(size: size * 0.4))
                                    .foregroundColor(.gray)
                            case .empty:
                                ProgressView()
                                    .scaleEffect(0.5)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundColor(.gray)
                    }
                }
            )
            .clipShape(Circle())
            .overlay(Circle().stroke(AppColor.background, lineWidth: 2))
    }
}

