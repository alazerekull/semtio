//
//  FriendsView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var chatStore: ChatStore
    @State private var selectedTab: String
    @State private var searchText = ""
    
    // Navigation state for chat
    @State private var selectedChatThreadId: String? = nil
    @State private var isNavigatingToChat = false
    @State private var loadingFriendId: String? = nil
    @State private var chatError: String? = nil
    
    // Tab definitions
    static let tabFriends = "Arkadaşların"
    static let tabRequests = "İstekler"
    static let tabSearch = "Ara"
    
    init(initialTab: String = FriendsView.tabFriends) {
        _selectedTab = State(initialValue: initialTab)
    }
    
    var filteredFriends: [AppUser] {
        if searchText.isEmpty {
            return friendStore.friends
        } else {
            return friendStore.friends.filter {
                $0.fullName.lowercased().contains(searchText.lowercased()) ||
                ($0.username?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
    }
    
    // Dynamic Tab Title for Requests using Single Source of Truth
    private var requestsTabTitle: String {
        let count = friendStore.incomingCount
        return count > 0 ? "İstekler (\(count))" : "İstekler"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Simple Header
                Text("Arkadaşlar")
                    .font(AppFont.headline)
                    .padding(.vertical)
                
                // Custom Segmented Control
                HStack(spacing: 4) {
                    FriendTabButton(title: FriendsView.tabFriends, isSelected: selectedTab == FriendsView.tabFriends) { selectedTab = FriendsView.tabFriends }
                    FriendTabButton(title: requestsTabTitle, isSelected: selectedTab == FriendsView.tabRequests) { selectedTab = FriendsView.tabRequests }
                    FriendTabButton(title: FriendsView.tabSearch, isSelected: selectedTab == FriendsView.tabSearch) { selectedTab = FriendsView.tabSearch }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom)
                
                // Search Bar for "Ara" tab or filter (only for friends list or global search)
                if selectedTab == FriendsView.tabSearch || selectedTab == FriendsView.tabFriends {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        TextField(selectedTab == FriendsView.tabSearch ? "Arkadaş ara..." : "Arkadaşlarında ara...", text: $searchText)
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
                
                // Content Area
                if selectedTab == FriendsView.tabRequests {
                    requestsContent
                } else if selectedTab == FriendsView.tabSearch {
                    FriendSearchScreen()
                } else {
                    friendsListContent
                }
                
                Spacer()
            }
            .background(Color.semtioBackground)
            .navigationDestination(isPresented: $isNavigatingToChat) {
                if let threadId = selectedChatThreadId {
                    ChatScreen(threadId: threadId)
                }
            }
            .alert("Hata", isPresented: Binding(
                get: { chatError != nil },
                set: { if !$0 { chatError = nil } }
            )) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(chatError ?? "")
            }
        }
        .task {
            await friendStore.loadIfNeeded(userId: userStore.currentUser.id)
            await friendStore.loadIncomingRequests(force: false)
        }
        .onAppear {
            // Start realtime listener for incoming requests
            friendStore.startListeningForIncomingRequests()
        }
        .onDisappear {
            // Stop listener when view disappears
            friendStore.stopListeningForIncomingRequests()
        }
    }
    
    // MARK: - Open Chat with Friend
    func openChat(with friend: AppUser) {
        guard loadingFriendId == nil else { return }
        loadingFriendId = friend.id
        
        Task {
            do {
                let thread = try await chatStore.getOrCreateDMThread(
                    currentUserId: userStore.currentUser.id,
                    otherUserId: friend.id
                )
                await MainActor.run {
                    selectedChatThreadId = thread.id
                    isNavigatingToChat = true
                    loadingFriendId = nil
                }
            } catch {
                await MainActor.run {
                    chatError = "Sohbet oluşturulamadı: \(error.localizedDescription)"
                    loadingFriendId = nil
                }
            }
        }
    }
    
    // MARK: - Friends List Content
    private var friendsListContent: some View {
        ScrollView {
            if friendStore.isLoading {
                ProgressView().padding()
            } else if filteredFriends.isEmpty {
                EmptyStateView(
                    iconName: "person.2.slash",
                    title: "Arkadaşın Yok",
                    subtitle: "Henüz kimseyle arkadaş değilsin. Yeni insanlarla tanışmak için 'Ara' sekmesini kullan.",
                    actionTitle: nil,
                    action: nil
                )
                .padding(.top, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredFriends) { friend in
                        FriendRowView(
                            friend: friend,
                            isLoading: loadingFriendId == friend.id,
                            onMessageTapped: { openChat(with: friend) }
                        )
                    }
                    
                    if friendStore.hasMoreFriends && searchText.isEmpty {
                        ProgressView()
                            .padding()
                            .onAppear {
                                Task {
                                    await friendStore.loadMoreFriends(userId: userStore.currentUser.id)
                                }
                            }
                    }
                }
                .padding()
            }
        }
        .refreshable {
            await friendStore.loadFriends(userId: userStore.currentUser.id)
        }
    }
    
    // MARK: - Requests Content (Phase 1 Polish)
    @ViewBuilder
    private var requestsContent: some View {
        Group {
            if friendStore.isIndexBuildingIncomingRequests {
                RequestsLoadingStateView(
                    title: "İstekler hazırlanıyor…",
                    subtitle: "Sistem kısa süreli bir hazırlık yapıyor. Birazdan otomatik yüklenecek."
                )
            } else if friendStore.isLoadingIncomingRequests && friendStore.incomingRequests.isEmpty {
                RequestsLoadingStateView(
                    title: "İstekler yükleniyor…",
                    subtitle: "Lütfen bekleyin."
                )
            } else if let err = friendStore.incomingRequestsErrorMessage, friendStore.incomingRequests.isEmpty {
                RequestsErrorStateView(
                    title: "İstekler yüklenemedi",
                    subtitle: "Lütfen tekrar deneyin.",
                    debugMessage: err
                ) {
                    Task { await friendStore.loadIncomingRequests(force: true) }
                }
            } else if friendStore.incomingRequests.isEmpty {
                RequestsEmptyStateView(
                    title: "Henüz istek yok",
                    subtitle: "Biri sana arkadaşlık isteği gönderdiğinde burada görünecek."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(friendStore.incomingRequests, id: \.id) { req in
                            FriendRequestCard(
                                request: req,
                                isProcessing: friendStore.processingRequestIds.contains(req.id),
                                onAccept: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { }
                                    Task {
                                        await friendStore.accept(request: req)
                                        await friendStore.loadFriends(userId: userStore.currentUser.id)
                                    }
                                },
                                onReject: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { }
                                    Task {
                                        await friendStore.reject(request: req)
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
        }
        .task {
            await friendStore.loadIncomingRequests(force: false)
        }
        .refreshable {
            await friendStore.loadIncomingRequests(force: true)
        }
    }
}

// MARK: - Modern Request Card
private struct FriendRequestCard: View {
    let request: FriendRequest
    let isProcessing: Bool
    let onAccept: () -> Void
    let onReject: () -> Void

    private var title: String {
        if let n = request.fromName, !n.isEmpty { return n }
        return "Yeni Kullanici"
    }

    private var subtitle: String {
        return "@\(request.fromUid.prefix(10))..."
    }

    private var initials: String {
        if let name = request.fromName, !name.isEmpty {
            return String(name.prefix(1)).uppercased()
        }
        return "?"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    if let avatarURL = request.fromAvatar, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            case .failure(_), .empty:
                                avatarFallback
                            @unknown default:
                                avatarFallback
                            }
                        }
                    } else {
                        avatarFallback
                    }
                }
                .frame(width: 50, height: 50)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColor.textPrimary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(AppColor.textSecondary)
                }
                
                Spacer()
            }
            
            // Buttons Row
            HStack(spacing: 12) {
                Button(action: onReject) {
                    Text("Reddet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color(white: 0.92))
                        .cornerRadius(8)
                }
                .disabled(isProcessing)
                
                Button(action: onAccept) {
                    ZStack {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Kabul Et")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color.semtioPrimary) // Use app primary color (purple/pink)
                    .cornerRadius(8)
                }
                .disabled(isProcessing)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var avatarFallback: some View {
        Circle()
            .fill(Color(white: 0.9))
            .frame(width: 50, height: 50)
            .overlay(
                Text(initials)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.gray)
            )
    }
}

// MARK: - State Views (Phase 1)

private struct RequestsEmptyStateView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 46))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundColor(AppColor.textPrimary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
}

private struct RequestsLoadingStateView: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(title).font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
}

private struct RequestsErrorStateView: View {
    let title: String
    let subtitle: String
    let debugMessage: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundColor(.gray.opacity(0.55))
            
            Text(title).font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(AppColor.textSecondary)
            
            #if DEBUG
            Text(debugMessage)
                .font(.footnote)
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            #endif
            
            Button("Tekrar Dene", action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
}

// MARK: - Tab Button
struct FriendTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .black : .gray)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(isSelected ? Color.white : Color.clear)
                .cornerRadius(20)
        }
    }
}

// MARK: - Friend Row
struct FriendRowView: View {
    let friend: AppUser
    var isLoading: Bool = false
    var onMessageTapped: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.semtioPrimary.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                if let assetName = friend.avatarAssetName {
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    Text(String(friend.fullName.prefix(1)).uppercased())
                        .font(AppFont.headline)
                        .foregroundColor(.semtioPrimary)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.fullName)
                    .font(AppFont.subheadline)
                if let username = friend.username {
                    Text("@\(username)")
                        .font(AppFont.footnote)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Button(action: { onMessageTapped?() }) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Mesaj")
                            .font(AppFont.footnote)
                            .foregroundColor(.semtioPrimary)
                    }
                }
                .frame(width: 60, height: 28)
                .background(Color.semtioPrimary.opacity(0.1))
                .cornerRadius(12)
            }
            .disabled(isLoading)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}
