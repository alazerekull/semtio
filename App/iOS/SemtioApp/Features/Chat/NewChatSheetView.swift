//
//  NewChatSheetView.swift
//  SemtioApp
//
//  Created by Antigravity on 2026-01-20.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct NewChatSheetView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var chatStore: ChatStore
    @EnvironmentObject var friendStore: FriendStore
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""
    @State private var isCreatingChat = false
    @State private var showFriendSearch = false
    @State private var showGroupCreation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)

                // Quick Actions
                if searchText.isEmpty {
                    quickActionsSection
                        .padding(.top, Spacing.md)
                }

                // Content
                if friendStore.isLoading {
                    loadingView
                } else if !searchText.isEmpty {
                    searchResultsView
                } else if friendStore.friends.isEmpty {
                    emptyFriendsView
                } else {
                    friendsListView
                }
            }
            .background(AppColor.background)
            .navigationTitle("Yeni Sohbet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                    .foregroundColor(AppColor.primaryFallback)
                }
            }
            .onChange(of: searchText) { _, newValue in
                Task {
                    if !newValue.isEmpty {
                        await friendStore.search(query: newValue)
                    } else {
                        friendStore.clearSearch()
                    }
                }
            }
            .onAppear {
                if let uid = appState.auth.uid {
                    Task { await friendStore.loadFriends(userId: uid) }
                }
            }
            .disabled(isCreatingChat)
            .overlay {
                if isCreatingChat {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            VStack(spacing: Spacing.md) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                    .tint(.white)
                                Text("Sohbet oluşturuluyor...")
                                    .font(AppFont.caption)
                                    .foregroundColor(AppColor.onPrimary)
                            }
                            .padding(Spacing.lg)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(Radius.md)
                        }
                }
            }
            .sheet(isPresented: $showFriendSearch) {
                FriendSearchView(
                    userStore: appState.userStore,
                    notificationRepo: appState.notificationRepo
                )
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showGroupCreation) {
                CreateGroupView()
                    .environmentObject(appState)
                    .environmentObject(chatStore)
                    .environmentObject(friendStore)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(AppFont.callout)
                .foregroundColor(AppColor.textSecondary)

            TextField("Kişi ara...", text: $searchText)
                .font(AppFont.body)
                .foregroundColor(AppColor.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(AppFont.callout)
                        .foregroundColor(AppColor.textSecondary)
                }
            }
        }
        .padding(Spacing.md)
        .background(AppColor.surface)
        .cornerRadius(Radius.md)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Hızlı Eylemler")
                .font(AppFont.captionBold)
                .foregroundColor(AppColor.textSecondary)
                .padding(.horizontal, Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    QuickActionCard(
                        icon: "person.badge.plus",
                        title: "Arkadaş Ekle",
                        color: .blue
                    ) {
                        showFriendSearch = true
                    }

                    QuickActionCard(
                        icon: "person.3.fill",
                        title: "Grup Oluştur",
                        color: .purple
                    ) {
                        showGroupCreation = true
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColor.primaryFallback)
            Text("Arkadaşlar yükleniyor...")
                .font(AppFont.subheadline)
                .foregroundColor(AppColor.textSecondary)
            Spacer()
        }
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if friendStore.searchResults.isEmpty {
                    VStack(spacing: Spacing.md) {
                        Spacer().frame(height: 60)

                        Image(systemName: "person.slash")
                            .font(.system(size: 48))
                            .foregroundColor(AppColor.textSecondary.opacity(0.5))

                        Text("Kullanıcı bulunamadı")
                            .font(AppFont.subheadline)
                            .foregroundColor(AppColor.textSecondary)

                        Text("Farklı bir isim deneyin")
                            .font(AppFont.caption)
                            .foregroundColor(AppColor.textSecondary.opacity(0.7))
                    }
                } else {
                    ForEach(friendStore.searchResults) { user in
                        Button {
                            startChat(with: user)
                        } label: {
                            ModernUserRow(user: user)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.top, Spacing.md)
        }
    }

    // MARK: - Empty Friends View

    private var emptyFriendsView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColor.primaryFallback.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppColor.primaryFallback.opacity(0.6))
            }

            VStack(spacing: Spacing.sm) {
                Text("Henüz arkadaş yok")
                    .font(AppFont.headline)
                    .foregroundColor(AppColor.textPrimary)

                Text("Arkadaş ekleyerek sohbet başlatabilirsin")
                    .font(AppFont.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                dismiss()
                // Navigate to friend search
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "person.badge.plus")
                    Text("Arkadaş Bul")
                }
                .font(AppFont.subheadline)
                .foregroundColor(AppColor.onPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(AppColor.primaryFallback)
                .cornerRadius(Radius.pill)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
    }

    // MARK: - Friends List

    private var friendsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Section Header
                HStack {
                    Text("Arkadaşlarım")
                        .font(AppFont.captionBold)
                        .foregroundColor(AppColor.textSecondary)
                    Spacer()
                    Text("\(friendStore.friends.count) kişi")
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.textSecondary.opacity(0.7))
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)

                ForEach(friendStore.friends) { user in
                    Button {
                        startChat(with: user)
                    } label: {
                        ModernUserRow(user: user)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.top, Spacing.md)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Actions

    private func startChat(with user: User) {
        isCreatingChat = true

        Task {
            if let currentUid = appState.auth.uid {
                if let threadId = await chatStore.createDM(with: user.id, currentUserId: currentUid) {
                    await MainActor.run {
                        isCreatingChat = false
                        dismiss()
                        appState.deepLinkChatThreadId = threadId
                    }
                } else {
                    await MainActor.run {
                        isCreatingChat = false
                    }
                }
            } else {
                await MainActor.run {
                    isCreatingChat = false
                }
            }
        }
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(AppFont.caption)
                    .foregroundColor(AppColor.textPrimary)
            }
            .frame(width: 80)
        }
    }
}

// MARK: - Modern User Row

struct ModernUserRow: View {
    let user: User

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            avatarView

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(AppFont.subheadline)
                    .foregroundColor(AppColor.textPrimary)

                if let username = user.username {
                    Text("@\(username)")
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.textSecondary)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColor.textSecondary.opacity(0.5))
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(Color.clear)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var avatarView: some View {
        if let avatarURL = user.avatarURL, let url = URL(string: avatarURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    avatarPlaceholder
                case .empty:
                    ProgressView()
                        .frame(width: 48, height: 48)
                @unknown default:
                    avatarPlaceholder
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColor.primaryFallback, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)

            Text(String(user.displayName.prefix(1)).uppercased())
                .font(AppFont.headline)
                .foregroundColor(AppColor.onPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    NewChatSheetView()
        .environmentObject(AppState(
            session: SessionManager(),
            theme: AppThemeManager(),
            location: LocationManager()
        ))
        .environmentObject(ChatStore(repo: MockChatRepository()))
        .environmentObject(FriendStore(repo: MockFriendRepository(), notificationRepo: MockNotificationRepository(), userStore: UserStore(repo: MockUserRepository())))
}
