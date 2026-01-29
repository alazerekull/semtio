//
//  ChatListScreen.swift
//  SemtioApp
//
//  Copyright © 2026 Oguzhan Cankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

enum ChatFilter: String, CaseIterable {
    case all = "Tumu"
    case unread = "Okunmamis"
    case groups = "Gruplar"
    case archive = "Arsiv"
    case hidden = "Gizli"
}

struct ChatListScreen: View {
    @EnvironmentObject var chatStore: ChatStore
    @EnvironmentObject var userStore: UserStore
    @StateObject private var pinManager = HiddenPinManager.shared

    @State private var searchQuery = ""
    @State private var showNewChat = false
    @State private var selectedFilter: ChatFilter = .all

    // Hidden Auth UI State
    @State private var showHiddenAuth = false
    @State private var hiddenAuthMode: HiddenAuthMode = .verify
    @State private var pendingThreadToHide: ChatThread?
    @State private var pendingFilterChange = false

    // Navigation State
    @State private var selectedThread: ChatThread?

    var filteredThreads: [ChatThread] {
        let userId = userStore.currentUser.id

        // 1. Base Filter
        let threads = chatStore.threads.filter { thread in
            let isHidden = thread.hiddenBy.contains(userId)

            // Hidden Logic
            if selectedFilter == .hidden {
                return isHidden
            } else {
                // For other tabs, exclude hidden chats
                if isHidden { return false }
            }

            let isArchived = thread.archivedBy.contains(userId)
            let isDeleted = thread.deletedBy.contains(userId)

            // Never show deleted
            if isDeleted { return false }

            if selectedFilter == .archive {
                return isArchived
            } else {
                return !isArchived
            }
        }

        // 2. Search
        if !searchQuery.isEmpty {
            return threads.filter { thread in
                thread.displayTitle(for: userId).localizedCaseInsensitiveContains(searchQuery)
            }
        }

        // 3. Category Filter
        switch selectedFilter {
        case .all, .archive, .hidden:
            return threads
        case .unread:
            return threads.filter { $0.unreadCount(for: userId) > 0 }
        case .groups:
            return threads.filter { $0.type == .group || $0.type == .event }
        }
    }

    @State private var isSelectionMode = false
    @State private var selectedThreadIds: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Search Bar
                    if !isSelectionMode {
                        searchBarView
                    }
                    
                    // Filter Chips
                    if !isSelectionMode {
                        filterChipsView
                    } else {
                        // Selection Header Info
                        HStack {
                            Text("\(selectedThreadIds.count) Sohbet Secildi")
                                .font(.headline)
                                .foregroundColor(AppColor.textPrimary)
                            Spacer()
                        }
                        .padding()
                        .background(AppColor.surface)
                    }

                    // Content
                    if filteredThreads.isEmpty {
                        EmptyStateView(
                            iconName: emptyStateIcon,
                            title: emptyStateTitle,
                            subtitle: emptyStateSubtitle,
                            actionTitle: selectedFilter == .all ? "Yeni Sohbet Baslat" : nil,
                            action: selectedFilter == .all ? { showNewChat = true } : nil
                        )
                    } else {
                        chatListView
                    }
                    
                    // Bottom Action Bar (Selection Mode)
                    if isSelectionMode {
                        VStack(spacing: 0) {
                            Divider()
                            HStack {
                                // Delete
                                Button(action: handleDeleteSelected) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "trash")
                                        Text("Sil")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                }
                                
                                Spacer()
                                
                                // Archive/Unarchive
                                if selectedFilter != .archive {
                                    Button(action: handleArchiveSelected) {
                                        VStack(spacing: 4) {
                                            Image(systemName: "archivebox")
                                            Text(selectedFilter == .archive ? "Cikar" : "Arsivle")
                                                .font(.caption)
                                        }
                                        .foregroundColor(AppColor.textPrimary)
                                        .frame(maxWidth: .infinity)
                                    }
                                    Spacer()
                                } else {
                                     Button(action: handleUnarchiveSelected) {
                                        VStack(spacing: 4) {
                                            Image(systemName: "arrow.uturn.backward")
                                            Text("Geri Al")
                                                .font(.caption)
                                        }
                                        .foregroundColor(AppColor.textPrimary)
                                        .frame(maxWidth: .infinity)
                                    }
                                    Spacer()
                                }
                                
                                // Hide/Unhide
                                if selectedFilter != .hidden {
                                    Button(action: handleHideSelected) {
                                        VStack(spacing: 4) {
                                            Image(systemName: "eye.slash")
                                            Text("Gizle")
                                                .font(.caption)
                                        }
                                        .foregroundColor(AppColor.textPrimary)
                                        .frame(maxWidth: .infinity)
                                    }
                                } else {
                                    Button(action: handleUnhideSelected) {
                                        VStack(spacing: 4) {
                                            Image(systemName: "eye")
                                            Text("Goster")
                                                .font(.caption)
                                        }
                                        .foregroundColor(AppColor.textPrimary)
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                            .padding()
                            .background(AppColor.surface)
                        }
                        .transition(.move(edge: .bottom))
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
                    .zIndex(1)
                }
            }
            .background(AppColor.background)
            .navigationTitle("Mesajlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                 ToolbarItem(placement: .navigationBarLeading) {
                     if isSelectionMode {
                         Button("Vazgeç") {
                             isSelectionMode = false
                             selectedThreadIds.removeAll()
                         }
                         .foregroundColor(AppColor.textPrimary)
                     } else {
                         Button(action: {
                             handleHiddenCheck()
                         }) {
                             HStack(spacing: 4) {
                                 Image(systemName: "lock.fill")
                                     .font(.system(size: 14))
                                 Text("Gizli")
                                     .font(.system(size: 14, weight: .medium))
                             }
                             .foregroundColor(AppColor.textSecondary)
                             .padding(.horizontal, 8)
                             .padding(.vertical, 4)
                             .background(AppColor.surface)
                             .cornerRadius(12)
                         }
                     }
                 }
                 
                 ToolbarItemGroup(placement: .navigationBarTrailing) {
                     if isSelectionMode {
                         // Empty
                     } else {
                        HStack(spacing: 16) {
                             Button(action: {
                                 isSelectionMode = true
                             }) {
                                 Text("Seç")
                                     .font(.system(size: 16, weight: .medium))
                                     .foregroundColor(AppColor.textPrimary)
                             }
                             
                             Button(action: { showNewChat = true }) {
                                 Image(systemName: "square.and.pencil")
                                     .font(.system(size: 18, weight: .semibold))
                                     .foregroundColor(Color.semtioPrimary)
                             }
                         }
                     }
                 }
             }
            .animation(.spring(response: 0.3), value: showHiddenAuth)
            .animation(.easeInOut, value: isSelectionMode)
        }
        .task {
            chatStore.startListeningThreads(userId: userStore.currentUser.id)
            _ = await pinManager.checkPinStatus()
        }
        .sheet(isPresented: $showNewChat) {
            NewChatSheet()
        }
    }

    // MARK: - Subviews

    private var searchBarView: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColor.textSecondary)

            TextField("Sohbet ara...", text: $searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .foregroundColor(AppColor.textPrimary)

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColor.textSecondary)
                }
            }
        }
        .padding(Spacing.md)
        .background(AppColor.surface)
        .cornerRadius(Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(AppColor.border, lineWidth: 1)
        )
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ChatFilter.allCases, id: \.self) { filter in
                    Button(action: { handleFilterSelection(filter) }) {
                        HStack(spacing: 4) {
                            if filter == .hidden {
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                            }
                            Text(filter.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            // Show badge for unread in hidden
                            if filter == .hidden {
                                let hiddenUnread = hiddenChatsUnreadCount
                                if hiddenUnread > 0 {
                                    Text("\(hiddenUnread)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedFilter == filter ? Color.semtioPrimary : Color.semtioBackground)
                        .foregroundColor(selectedFilter == filter ? .white : AppColor.textPrimary)
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
    }

    private var chatListView: some View {
        List {
            ForEach(filteredThreads) { thread in
                HStack {
                    if isSelectionMode {
                        Image(systemName: selectedThreadIds.contains(thread.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selectedThreadIds.contains(thread.id) ? Color.semtioPrimary : .gray)
                            .font(.system(size: 22))
                            .onTapGesture {
                                toggleSelection(thread.id)
                            }
                    }
                    
                    // Logic: If selection mode, tap anywhere toggles. If not, it navs.
                    // To achieve this cleanly with NavigationLink, we can conditionally disable it?
                    // Or keep NavLink but intercept tap?
                    // Easiest: ZStack.
                    
                    ZStack {
                        if !isSelectionMode {
                            NavigationLink(value: thread) {
                                EmptyView()
                            }
                            .opacity(0)
                        }
                        
                        ChatThreadRow(
                            thread: thread,
                            currentUserId: userStore.currentUser.id
                        )
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSelectionMode {
                        toggleSelection(thread.id)
                    } else {
                         // NavLink handles it, but since it's opacity 0 in ZStack, user taps Row.
                         // But standard NavLink(value:label:) is better if we can disable it.
                         // Let's use simpler approach:
                         // When isSelectionMode, replace NavLink with Button/Text.
                         // Actually Row is inside NavLink above.
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .swipeActions(edge: .leading) {
                    if !isSelectionMode {
                        Button(role: .destructive) {
                            Task { await chatStore.deleteThread(threadId: thread.id, userId: userStore.currentUser.id) }
                        } label: {
                            Label("Sil", systemImage: "trash.fill")
                        }
                    }
                }
                .swipeActions(edge: .trailing) {
                    if !isSelectionMode {
                        // Hide Action
                        Button {
                            if selectedFilter == .hidden {
                                 Task { await chatStore.unhideThread(threadId: thread.id, userId: userStore.currentUser.id) }
                            } else {
                                initiateHide(thread: thread)
                            }
                        } label: {
                            Label(selectedFilter == .hidden ? "Cikar" : "Gizle", systemImage: selectedFilter == .hidden ? "eye.fill" : "lock.fill")
                        }
                        .tint(.purple)
                        
                        // Archive Action
                        if selectedFilter != .hidden {
                            Button {
                                Task {
                                    if thread.archivedBy.contains(userStore.currentUser.id) {
                                        await chatStore.unarchiveThread(threadId: thread.id, userId: userStore.currentUser.id)
                                    } else {
                                        await chatStore.archiveThread(threadId: thread.id, userId: userStore.currentUser.id)
                                    }
                                }
                            } label: {
                                Label(thread.archivedBy.contains(userStore.currentUser.id) ? "Cikar" : "Arsivle", systemImage: "archivebox.fill")
                            }
                            .tint(.gray)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            chatStore.startListeningThreads(userId: userStore.currentUser.id)
        }
        .navigationDestination(for: ChatThread.self) { thread in
            ChatScreen(threadId: thread.id)
        }
    }

    // MARK: - Computed Properties

    private var hiddenChatsUnreadCount: Int {
        let userId = userStore.currentUser.id
        return chatStore.threads
            .filter { $0.hiddenBy.contains(userId) }
            .reduce(0) { $0 + $1.unreadCount(for: userId) }
    }

    // MARK: - Filter Logic

    private func handleHiddenCheck() {
        if selectedFilter == .hidden {
            // Already hidden, switch back to all
            selectedFilter = .all
        } else {
            // Trying to enter hidden
            Task {
                let hasPIN = await pinManager.checkPinStatus()
                await MainActor.run {
                    if hasPIN {
                        // Already setup, verify
                        hiddenAuthMode = .verify
                        pendingFilterChange = true
                        showHiddenAuth = true
                    } else {
                        // Not setup, creating might be confusing here just to VIEW empty list.
                        // Better to show create only when HIDING content.
                        // But standard flow: enter folder -> create PIN if useful?
                        // Let's stick to verify. If no PIN, maybe just allow entry but show empty?
                        // Reqt: "Kullanıcıdan şifre belirle" happens "İlk Gizlemede".
                        // So here if no PIN, user has no hidden chats.
                        // We can just Enter. Or show Verify if PIN exists.
                        hiddenAuthMode = .create // Or prompt "No hidden chats yet"
                         
                        if hasPIN {
                           hiddenAuthMode = .verify
                           pendingFilterChange = true
                           showHiddenAuth = true
                        } else {
                           // No PIN = No Hidden Chats guaranteed (per logic)
                           // Just let them in or show empty?
                           // Let's prompt creation or just show empty view.
                           // Actually request says: Top "Gizli" -> Password Enter -> Success -> Hidden Chats
                           
                           // If no PIN, we can switch filter directly?
                           selectedFilter = .hidden
                        }
                    }
                }
            }
        }
    }

    private func handleFilterSelection(_ filter: ChatFilter) {
        if filter == .hidden {
             handleHiddenCheck()
        } else {
            selectedFilter = filter
        }
    }

    private func initiateHide(thread: ChatThread) {
        Task {
            let hasPIN = await pinManager.checkPinStatus()
            await MainActor.run {
                if hasPIN {
                    // PIN zaten var, direkt gizle
                    Task {
                        await chatStore.hideThread(threadId: thread.id, userId: userStore.currentUser.id)

                        // Haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                } else {
                    // PIN yok, once sifre belirleme ekrani goster
                    // Sifre belirlendikten sonra bu sohbet gizlenecek
                    pendingThreadToHide = thread
                    hiddenAuthMode = .create
                    showHiddenAuth = true
                }
            }
        }
    }

    private func handleAuthCancel() {
        showHiddenAuth = false
        pendingFilterChange = false
        pendingThreadToHide = nil
    }
    
    // MARK: - Selection Helpers
    
    private func toggleSelection(_ id: String) {
        if selectedThreadIds.contains(id) {
            selectedThreadIds.remove(id)
        } else {
            selectedThreadIds.insert(id)
        }
    }
    
    private func handleDeleteSelected() {
        let threads = Array(selectedThreadIds)
        guard !threads.isEmpty else { return }
        
        Task {
            await chatStore.deleteThreads(threadIds: threads, userId: userStore.currentUser.id)
            await MainActor.run {
                isSelectionMode = false
                selectedThreadIds.removeAll()
            }
        }
    }
    
    private func handleArchiveSelected() {
        let threads = Array(selectedThreadIds)
        guard !threads.isEmpty else { return }
        
        Task {
            await chatStore.archiveThreads(threadIds: threads, userId: userStore.currentUser.id)
            await MainActor.run {
                isSelectionMode = false
                selectedThreadIds.removeAll()
            }
        }
    }
    
    private func handleUnarchiveSelected() {
        let threads = Array(selectedThreadIds)
        guard !threads.isEmpty else { return }
        
        Task {
            await chatStore.unarchiveThreads(threadIds: threads, userId: userStore.currentUser.id)
            await MainActor.run {
                isSelectionMode = false
                selectedThreadIds.removeAll()
            }
        }
    }
    
    private func handleHideSelected() {
        let threads = Array(selectedThreadIds)
        guard !threads.isEmpty else { return }
        
        Task {
            let hasPIN = await pinManager.checkPinStatus()
            await MainActor.run {
                if hasPIN {
                    // PIN var, direkt gizle
                    executeBatchHide()
                } else {
                    // PIN yok, oluştur
                    hiddenAuthMode = .create
                    showHiddenAuth = true
                    // pending thread'e gerek yok, batch olarak success'te halledeceğiz
                }
            }
        }
    }
    
    private func handleUnhideSelected() {
        let threads = Array(selectedThreadIds)
        guard !threads.isEmpty else { return }
        
        Task {
             await chatStore.unhideThreads(threadIds: threads, userId: userStore.currentUser.id)
             await MainActor.run {
                isSelectionMode = false
                selectedThreadIds.removeAll()
             }
        }
    }
    
    private func executeBatchHide() {
        let threads = Array(selectedThreadIds)
        Task {
            await chatStore.hideThreads(threadIds: threads, userId: userStore.currentUser.id)
            await MainActor.run {
                isSelectionMode = false
                selectedThreadIds.removeAll()
                showHiddenAuth = false
            }
        }
    }
    
    // Auth Success override for Batch
    // We need to distinguish between Single Hide and Batch Hide in onSuccess.
    // Ideally we check if isSelectionMode is on.

    private func handleAuthSuccess() {
        if isSelectionMode {
             executeBatchHide()
             return
        }
        
        showHiddenAuth = false

        if pendingFilterChange {
            selectedFilter = .hidden
            pendingFilterChange = false
        }

        if let thread = pendingThreadToHide {
            Task {
                await chatStore.hideThread(threadId: thread.id, userId: userStore.currentUser.id)
                pendingThreadToHide = nil

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }

    // MARK: - Empty State Helpers

    private var emptyStateIcon: String {
        switch selectedFilter {
        case .hidden: return "eye.slash.fill"
        case .archive: return "archivebox"
        default: return "message.fill"
        }
    }

    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all: return "Henuz mesajiniz yok"
        case .unread: return "Okunmamis mesaj yok"
        case .groups: return "Grup sohbeti yok"
        case .archive: return "Arsivlenmis mesaj yok"
        case .hidden: return "Gizli sohbet yok"
        }
    }

    private var emptyStateSubtitle: String {
        switch selectedFilter {
        case .all: return "Arkadaslarinizla sohbet baslasin!"
        case .unread: return "Tum mesajlarinizi okudunuz."
        case .groups: return "Katildiginiz etkinliklerin gruplari burada gorunur."
        case .archive: return "Sohbetleri sola kaydirarak arsivleyebilirsiniz."
        case .hidden: return "Sohbetleri sola kaydirarak gizleyebilirsiniz."
        }
    }
}

// MARK: - Thread Row

struct ChatThreadRow: View {
    let thread: ChatThread
    let currentUserId: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(thread.type == .dm ? Color.semtioPrimary.opacity(0.15) : Color.purple.opacity(0.15))
                    .frame(width: ComponentSize.avatarMedium, height: ComponentSize.avatarMedium)

                Image(systemName: thread.type == .dm ? "person.fill" : "person.2.fill")
                    .font(.title3)
                    .foregroundColor(thread.type == .dm ? Color.semtioPrimary : .purple)

                // Online indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle().stroke(AppColor.surface, lineWidth: 2)
                    )
                    .offset(x: 16, y: 16)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(thread.displayTitle(for: currentUserId))
                    .font(AppFont.subheadline)
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)

                if let lastMsg = thread.lastMessage {
                    HStack(spacing: 4) {
                        if lastMsg.senderId == currentUserId {
                            Text("Sen:")
                                .foregroundColor(AppColor.textSecondary)
                        }
                        Text(lastMsg.text)
                            .foregroundColor(AppColor.textSecondary)
                            .lineLimit(1)
                    }
                    .font(AppFont.caption)
                }
            }

            Spacer()

            // Time & Badge
            VStack(alignment: .trailing, spacing: 4) {
                if let lastMsg = thread.lastMessage {
                    Text(timeAgo(lastMsg.createdAt))
                        .font(.caption2)
                        .foregroundColor(AppColor.textSecondary)
                }

                // Unread badge
                let unread = thread.unreadCount(for: currentUserId)
                if unread > 0 {
                    Text("\(unread)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColor.onPrimary)
                        .frame(width: 20, height: 20)
                        .background(Color.semtioPrimary)
                        .clipShape(Circle())
                }
            }
        }
        .padding(Spacing.md)
        .background(AppColor.surface)
        .cornerRadius(Radius.md)
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - New Chat Sheet

struct NewChatSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                EmptyStateView(
                    iconName: "person.3.fill",
                    title: "Yeni Sohbet",
                    subtitle: "Sohbet baslatmak icin arkadasini sec.",
                    actionTitle: nil,
                    action: nil
                )
            }
            .navigationTitle("Yeni Mesaj")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Iptal") { dismiss() }
                }
            }
        }
    }
}

// MARK: - ChatThread Extension

extension ChatThread {
    func displayTitle(for currentUserId: String) -> String {
        if let title = title {
            return title
        }
        // For DM, show other participant's ID (in real app, fetch name)
        let others = participants.filter { $0 != currentUserId }
        return others.first ?? "Sohbet"
    }

    var unreadCount: Int {
        // Fallback for mock if needed
        return 0
    }
}
