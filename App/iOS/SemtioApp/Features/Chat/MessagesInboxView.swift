//
//  MessagesInboxView.swift
//  SemtioApp
//
//  Created by Antigravity on 2026-01-20.
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct MessagesInboxView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var chatStore: ChatStore
    @EnvironmentObject var friendStore: FriendStore

    @State private var searchText = ""
    @State private var isShowingNewChat = false
    @State private var selectedFilter: ChatFilter = .all

    enum ChatFilter: String, CaseIterable {
        case all = "Tümü"
        case unread = "Okunmamış"
        case groups = "Gruplar"
        case archived = "Arşiv"
        case hidden = "Gizli"
    }

    // Hidden Auth State
    @State private var showHiddenAuth = false
    @State private var hiddenAuthMode: HiddenAuthMode = .verify
    @State private var hiddenUnlocked = false
    @State private var pendingHideThreadId: String?

    // Delete Confirm
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteThreadId: String?

    // Undo Toast
    @State private var undoToast: UndoToastData?

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Search Bar
                    searchBar
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.md)

                    // Filter Pills
                    filterPills
                        .padding(.top, Spacing.md)

                    // Hidden chats header bar
                    if selectedFilter == .hidden && hiddenUnlocked {
                        hiddenHeaderBar
                    }

                    // Chat List
                    if chatStore.isLoading && chatStore.threads.isEmpty {
                        loadingView
                    } else if selectedFilter == .hidden && !hiddenUnlocked {
                        // Don't show content until unlocked
                        hiddenLockedView
                    } else if filteredChats.isEmpty {
                        emptyStateView
                    } else {
                        chatListView
                    }
                }

                // Hidden Auth Overlay
                if showHiddenAuth {
                    HiddenAuthView(
                        mode: hiddenAuthMode,
                        onSuccess: handleAuthSuccess,
                        onCancel: handleAuthCancel
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(2)
                }

                // Undo Toast
                if let toast = undoToast {
                    VStack {
                        Spacer()
                        undoToastView(toast)
                            .padding(.bottom, 120)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(3)
                }
            }

            // Delete confirmation dialog
            .alert("Sohbet silinsin mi?", isPresented: $showDeleteConfirm) {
                Button("Sil", role: .destructive) {
                    if let threadId = pendingDeleteThreadId, let userId = appState.auth.uid {
                        Task {
                            await chatStore.deleteThread(threadId: threadId, userId: userId)
                        }
                    }
                    pendingDeleteThreadId = nil
                }
                Button("Vazgeç", role: .cancel) {
                    pendingDeleteThreadId = nil
                }
            }
            .background(AppColor.background)
            .navigationTitle("Sohbet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(AppColor.primaryFallback)
                    }
                }
            }
            .sheet(isPresented: $isShowingNewChat) {
                NewChatSheetView()
            }
            .onAppear {
                if let uid = appState.auth.uid {
                    chatStore.startListeningThreads(userId: uid)
                }
            }
            .onChange(of: selectedFilter) { _, newFilter in
                // Lock hidden view when switching away
                if newFilter != .hidden {
                    hiddenUnlocked = false
                }
                // Trigger auth when switching to hidden
                if newFilter == .hidden {
                    triggerHiddenAuth()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: undoToast?.id)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(AppFont.callout)
                .foregroundColor(AppColor.textSecondary)

            TextField("Sohbet veya kişi ara...", text: $searchText)
                .font(AppFont.body)
                .foregroundColor(AppColor.textPrimary)

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

    // MARK: - Filter Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(ChatFilter.allCases, id: \.self) { filter in
                    FilterPillButton(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter,
                        badgeCount: badgeCount(for: filter),
                        icon: filter == .hidden ? "lock.fill" : nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func badgeCount(for filter: ChatFilter) -> Int {
        guard let userId = appState.auth.uid else { return 0 }

        switch filter {
        case .all:
            return 0
        case .unread:
            return allChats.filter { $0.unreadCount > 0 }.count
        case .groups:
            return 0
        case .archived:
            return chatStore.threads.filter { $0.archivedBy.contains(userId) }.count
        case .hidden:
            return chatStore.threads.filter { $0.hiddenBy.contains(userId) }.count
        }
    }

    // MARK: - Hidden Header Bar (Gizli Tab)

    private var hiddenHeaderBar: some View {
        HStack {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColor.primaryFallback)

            Text("Gizli Sohbetler")
                .font(AppFont.headline)
                .foregroundColor(AppColor.textPrimary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    hiddenUnlocked = false
                    selectedFilter = .all
                }
            } label: {
                Text("Çık")
                    .font(AppFont.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColor.primaryFallback)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(AppColor.surface)
    }

    // MARK: - Hidden Locked View

    private var hiddenLockedView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColor.primaryFallback.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(AppColor.primaryFallback.opacity(0.6))
            }

            VStack(spacing: Spacing.sm) {
                Text("Gizli Sohbetler")
                    .font(AppFont.headline)
                    .foregroundColor(AppColor.textPrimary)

                Text("Erişim için doğrulama gerekli.")
                    .font(AppFont.body)
                    .foregroundColor(AppColor.textSecondary)
            }

            Button {
                triggerHiddenAuth()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "lock.open.fill")
                    Text("Kilidi Aç")
                }
                .font(AppFont.subheadline)
                .foregroundColor(AppColor.onPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(AppColor.primaryFallback)
                .cornerRadius(Radius.pill)
            }
            .padding(.top, Spacing.md)

            Spacer()
        }
    }

    // MARK: - Chat List

    private var chatListView: some View {
        List {
            ForEach(filteredChats) { chat in
                chatRow(for: chat)
                    // LEADING SWIPE (saga kaydir) = SIL (kirmizi)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDeleteThreadId = chat.id
                            showDeleteConfirm = true
                        } label: {
                            Label("Sil", systemImage: "trash.fill")
                        }
                    }
                    // TRAILING SWIPE (sola kaydir) = GIZLE (mor) + ARSIVLE (gri)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if selectedFilter == .hidden {
                            Button {
                                handleArchiveAction(chat.id)
                            } label: {
                                Label("Arsivle", systemImage: "archivebox.fill")
                            }
                            .tint(.gray)

                            Button {
                                handleUnhideAction(chat.id)
                            } label: {
                                Label("Goster", systemImage: "eye.fill")
                            }
                            .tint(.indigo)
                        } else if selectedFilter == .archived {
                            Button {
                                handleUnarchiveAction(chat.id)
                            } label: {
                                Label("Geri Al", systemImage: "tray.and.arrow.up.fill")
                            }
                            .tint(.blue)
                        } else {
                            Button {
                                handleArchiveAction(chat.id)
                            } label: {
                                Label("Arsivle", systemImage: "archivebox.fill")
                            }
                            .tint(.gray)

                            Button {
                                handleHideSwipeAction(chat.id)
                            } label: {
                                Label("Gizle", systemImage: "lock.fill")
                            }
                            .tint(AppColor.primaryFallback)
                        }
                    }
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func chatRow(for chat: ChatSummary) -> some View {
        NavigationLink {
            ChatScreen(threadId: chat.id)
        } label: {
            ModernChatRow(
                summary: chat,
                currentUserId: appState.auth.uid
            )
            .environmentObject(friendStore)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColor.primaryFallback)
            Text("Mesajlar yükleniyor...")
                .font(AppFont.subheadline)
                .foregroundColor(AppColor.textSecondary)
            Spacer()
        }
    }

    // MARK: - Undo Toast

    private func undoToastView(_ toast: UndoToastData) -> some View {
        HStack(spacing: Spacing.md) {
            Text(toast.message)
                .font(AppFont.subheadline)
                .foregroundColor(.white)

            Spacer()

            Button {
                toast.undoAction()
                withAnimation(.easeInOut(duration: 0.2)) {
                    undoToast = nil
                }
            } label: {
                Text("Geri Al")
                    .font(AppFont.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColor.primaryFallback)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(Color(uiColor: .darkGray))
        )
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Swipe Action Handlers

    private func handleHideSwipeAction(_ threadId: String) {
        Task {
            let hasPIN = await HiddenPinManager.shared.checkPinStatus()
            await MainActor.run {
                if hasPIN {
                    // PIN exists, hide directly with animation
                    executeHideWithAnimation(threadId)
                } else {
                    // No PIN, trigger PIN creation first
                    pendingHideThreadId = threadId
                    hiddenAuthMode = .create
                    showHiddenAuth = true
                }
            }
        }
    }

    private func executeHideWithAnimation(_ threadId: String) {
        guard let userId = appState.auth.uid else { return }

        // Haptic
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        Task {
            await chatStore.hideThread(threadId: threadId, userId: userId)
        }

        // Show undo toast
        showUndoToast(message: "Sohbet gizlendi") {
            if let userId = self.appState.auth.uid {
                Task {
                    await self.chatStore.unhideThread(threadId: threadId, userId: userId)
                }
            }
        }
    }

    private func handleArchiveAction(_ threadId: String) {
        guard let userId = appState.auth.uid else { return }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        Task {
            await chatStore.archiveThread(threadId: threadId, userId: userId)
        }

        showUndoToast(message: "Arşivlendi") {
            if let userId = self.appState.auth.uid {
                Task {
                    await self.chatStore.unarchiveThread(threadId: threadId, userId: userId)
                }
            }
        }
    }

    private func handleUnarchiveAction(_ threadId: String) {
        guard let userId = appState.auth.uid else { return }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        Task {
            await chatStore.unarchiveThread(threadId: threadId, userId: userId)
        }
    }

    private func handleUnhideAction(_ threadId: String) {
        guard let userId = appState.auth.uid else { return }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        Task {
            await chatStore.unhideThread(threadId: threadId, userId: userId)
        }
    }

    private func showUndoToast(message: String, undoAction: @escaping () -> Void) {
        withAnimation(.easeInOut(duration: 0.3)) {
            undoToast = UndoToastData(message: message, undoAction: undoAction)
        }

        // Auto-dismiss after 3 seconds
        let toastId = undoToast?.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.undoToast?.id == toastId {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.undoToast = nil
                }
            }
        }
    }

    // MARK: - Hidden Auth Flow

    private func triggerHiddenAuth() {
        Task {
            let hasPIN = await HiddenPinManager.shared.checkPinStatus()
            await MainActor.run {
                hiddenAuthMode = hasPIN ? .verify : .create
                showHiddenAuth = true
            }
        }
    }

    private func handleAuthSuccess() {
        if let threadId = pendingHideThreadId {
            // PIN just created, now hide the thread
            executeHideWithAnimation(threadId)
            pendingHideThreadId = nil
            showHiddenAuth = false
        } else {
            // Unlocking hidden tab
            hiddenUnlocked = true
            showHiddenAuth = false
        }
    }

    private func handleAuthCancel() {
        showHiddenAuth = false
        pendingHideThreadId = nil

        // If was trying to open hidden tab, go back to all
        if selectedFilter == .hidden && !hiddenUnlocked {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = .all
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppColor.primaryFallback.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: emptyStateIcon)
                    .font(.system(size: 48))
                    .foregroundColor(AppColor.primaryFallback.opacity(0.6))
            }

            VStack(spacing: Spacing.sm) {
                Text(emptyStateTitle)
                    .font(AppFont.headline)
                    .foregroundColor(AppColor.textPrimary)

                Text(emptyStateSubtitle)
                    .font(AppFont.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            if selectedFilter == .all {
                Button {
                    isShowingNewChat = true
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                        Text("Yeni Sohbet Başlat")
                    }
                    .font(AppFont.subheadline)
                    .foregroundColor(AppColor.onPrimary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(AppColor.primaryFallback)
                    .cornerRadius(Radius.pill)
                }
                .padding(.top, Spacing.md)
            }

            Spacer()
        }
    }

    private var emptyStateIcon: String {
        switch selectedFilter {
        case .all: return "bubble.left.and.bubble.right.fill"
        case .unread: return "bubble.left.and.bubble.right.fill"
        case .groups: return "person.3.fill"
        case .archived: return "archivebox.fill"
        case .hidden: return "lock.fill"
        }
    }

    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all: return "Henüz mesaj yok"
        case .unread: return "Okunmamış mesaj yok"
        case .groups: return "Grup sohbeti yok"
        case .archived: return "Arşivlenmiş sohbet yok"
        case .hidden: return "Gizli sohbet yok"
        }
    }

    private var emptyStateSubtitle: String {
        switch selectedFilter {
        case .all: return "Arkadaşlarınla sohbet başlat ve bağlantıda kal!"
        case .unread: return "Tüm mesajlarını okudun."
        case .groups: return "Etkinlik gruplarına katıl ve tanış!"
        case .archived: return "Arşivlediğin sohbetler burada görünür."
        case .hidden: return "Gizlediğin sohbetler burada görünür."
        }
    }

    // MARK: - Filtering

    private var allChats: [ChatSummary] {
        chatStore.groupChats + chatStore.dmChats
    }

    private var filteredChats: [ChatSummary] {
        guard let userId = appState.auth.uid else { return [] }

        var chats: [ChatSummary]

        switch selectedFilter {
        case .all:
            chats = allChats.filter { summary in
                if let thread = chatStore.threads.first(where: { $0.id == summary.id }) {
                    return !thread.archivedBy.contains(userId) && !thread.deletedBy.contains(userId) && !thread.hiddenBy.contains(userId)
                }
                return true
            }
        case .unread:
            chats = allChats.filter { summary in
                guard let thread = chatStore.threads.first(where: { $0.id == summary.id }) else { return false }
                return summary.unreadCount > 0 && !thread.archivedBy.contains(userId) && !thread.deletedBy.contains(userId) && !thread.hiddenBy.contains(userId)
            }
        case .groups:
            chats = chatStore.groupChats.filter { summary in
                if let thread = chatStore.threads.first(where: { $0.id == summary.id }) {
                    return !thread.archivedBy.contains(userId) && !thread.deletedBy.contains(userId) && !thread.hiddenBy.contains(userId)
                }
                return true
            }
        case .archived:
            chats = allChats.filter { summary in
                if let thread = chatStore.threads.first(where: { $0.id == summary.id }) {
                    return thread.archivedBy.contains(userId) && !thread.deletedBy.contains(userId)
                }
                return false
            }
        case .hidden:
            chats = allChats.filter { summary in
                if let thread = chatStore.threads.first(where: { $0.id == summary.id }) {
                    return thread.hiddenBy.contains(userId) && !thread.deletedBy.contains(userId)
                }
                return false
            }
        }

        // Apply search filter
        if !searchText.isEmpty {
            chats = chats.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        // Sort by last message time
        return chats.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

}

// MARK: - Undo Toast Data

private struct UndoToastData: Identifiable {
    let id = UUID()
    let message: String
    let undoAction: () -> Void
}

// MARK: - Filter Pill Button

struct FilterPillButton: View {
    let title: String
    let isSelected: Bool
    let badgeCount: Int
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                }

                Text(title)
                    .font(AppFont.captionBold)

                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isSelected ? AppColor.primaryFallback : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white : AppColor.primaryFallback)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? .white : AppColor.textPrimary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(isSelected ? AppColor.primaryFallback : AppColor.surface)
            .cornerRadius(Radius.pill)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.pill)
                    .stroke(isSelected ? Color.clear : AppColor.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Modern Chat Row

struct ModernChatRow: View {
    let summary: ChatSummary
    let currentUserId: String?

    @EnvironmentObject var friendStore: FriendStore

    var otherUserId: String? {
        summary.memberIds.first(where: { $0 != currentUserId })
    }

    var displayTitle: String {
        if summary.type == .event || summary.title != "Sohbet" {
            return summary.title
        }
        if let otherId = otherUserId, let friend = friendStore.friends.first(where: { $0.id == otherId }) {
            return friend.displayName
        }
        return "Kullanıcı"
    }

    var displayAvatarURL: String? {
        if summary.type == .event { return summary.avatarURL }
        if let otherId = otherUserId, let friend = friendStore.friends.first(where: { $0.id == otherId }) {
            return friend.avatarURL
        }
        return summary.avatarURL
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                avatarView
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())

                // Online indicator (for DMs)
                if summary.type == .dm {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(AppColor.background, lineWidth: 2)
                        )
                        .offset(x: 2, y: 2)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayTitle)
                        .font(AppFont.subheadline)
                        .foregroundColor(AppColor.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(summary.timeAgo)
                        .font(AppFont.caption)
                        .foregroundColor(summary.unreadCount > 0 ? AppColor.primaryFallback : AppColor.textSecondary)
                }

                HStack(spacing: Spacing.xs) {
                    // Message type indicator
                    if let lastMessage = summary.lastMessage {
                        if lastMessage.contains("[Fotoğraf]") || lastMessage.contains("Fotoğraf") {
                            Image(systemName: "photo.fill")
                                .font(AppFont.caption)
                                .foregroundColor(AppColor.textSecondary)
                        }
                    }

                    Text(summary.lastMessage ?? "Henüz mesaj yok")
                        .font(summary.unreadCount > 0 ? AppFont.captionBold : AppFont.caption)
                        .foregroundColor(summary.unreadCount > 0 ? AppColor.textPrimary : AppColor.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    // Unread badge
                    if summary.unreadCount > 0 {
                        Text("\(summary.unreadCount)")
                            .font(AppFont.captionBold)
                            .foregroundColor(AppColor.onPrimary)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(AppColor.primaryFallback)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(
            summary.unreadCount > 0
                ? AppColor.primaryFallback.opacity(0.05)
                : Color.clear
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var avatarView: some View {
        if let url = displayAvatarURL, let validURL = URL(string: url) {
            AsyncImage(url: validURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    avatarPlaceholder
                case .empty:
                    ProgressView()
                        .frame(width: 56, height: 56)
                @unknown default:
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: summary.type == .event
                            ? [.orange, .pink]
                            : [AppColor.primaryFallback, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: summary.type == .event ? "person.3.fill" : "person.fill")
                .font(AppFont.title2)
                .foregroundColor(AppColor.onPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    MessagesInboxView()
        .environmentObject(AppState(
            session: SessionManager(),
            theme: AppThemeManager(),
            location: LocationManager()
        ))
        .environmentObject(ChatStore(repo: MockChatRepository()))
        .environmentObject(FriendStore(repo: MockFriendRepository(), notificationRepo: MockNotificationRepository(), userStore: UserStore(repo: MockUserRepository())))
}
