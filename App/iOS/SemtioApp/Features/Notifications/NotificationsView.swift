//
//  NotificationsView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Namespace private var animation // For matched geometry effect
    
    // UI State
    @State private var selectedTab: NotificationTab = .all
    
    enum NotificationTab: String, CaseIterable {
        case all = "Hepsi"
        case requests = "İstekler"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header (Custom Close Button + Title)
                headerView
                
                // Custom Tab Bar
                tabBar
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.lg)
                
                // Content
                Group {
                    if appState.notifications.isLoading && appState.notifications.notifications.isEmpty {
                        loadingView
                    } else if filteredNotifications.isEmpty {
                        emptyView
                    } else {
                        notificationsList
                    }
                }
            }
            .background(AppColor.background)
        }
        .task {
            await appState.notifications.refresh()
            // Ensure friend requests are loaded for action matching
            await appState.friends.loadIncomingRequests()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(AppFont.calloutBold)
                    .foregroundColor(AppColor.textPrimary)
                    .padding(10)
                    .background(AppColor.surface)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
            
            Text("Bildirimler")
                .font(AppFont.title2) // Large Title style
                .foregroundColor(AppColor.textPrimary)
                .padding(.leading, Spacing.md)
            
            Spacer()
            
            if appState.notifications.hasUnread {
                Button {
                    Task { await appState.notifications.markAllAsRead() }
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(AppFont.title3)
                        .foregroundColor(AppColor.textPrimary)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
    }
    
    // MARK: - Computed Data
    
    private var filteredNotifications: [AppNotification] {
        let all = appState.notifications.notifications
        switch selectedTab {
        case .all:
            return all.filter { $0.type != .friendRequest && $0.type != .eventInvite }
        case .requests:
            return all.filter { $0.type == .friendRequest || $0.type == .eventInvite }
        }
    }
    
    private var groupedNotifications: [(header: String, items: [AppNotification])] {
        let sorted = filteredNotifications.sorted { $0.createdAt > $1.createdAt }
        var result: [(String, [AppNotification])] = []
        
        let calendar = Calendar.current
        
        let today = sorted.filter { calendar.isDateInToday($0.createdAt) }
        let yesterday = sorted.filter { calendar.isDateInYesterday($0.createdAt) }
        let earlier = sorted.filter { !calendar.isDateInToday($0.createdAt) && !calendar.isDateInYesterday($0.createdAt) }
        
        if !today.isEmpty { result.append(("BUGÜN", today)) }
        if !yesterday.isEmpty { result.append(("DÜN", yesterday)) }
        if !earlier.isEmpty { result.append(("GEÇMİŞ", earlier)) }
        
        return result
    }

    // MARK: - Subviews
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(NotificationTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    ZStack {
                        if selectedTab == tab {
                            Capsule()
                                .fill(AppColor.primaryFallback)
                                .matchedGeometryEffect(id: "ActiveTab", in: animation)
                                .shadow(color: AppColor.primaryFallback.opacity(0.3), radius: 8, x: 0, y: 4)
                        } else {
                            Capsule()
                                .stroke(AppColor.border, lineWidth: 1)
                        }
                        
                        Text(tab.rawValue)
                            .font(AppFont.subheadline)
                            .foregroundColor(selectedTab == tab ? .white : AppColor.textSecondary)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 24)
                    }
                    .frame(height: 40)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColor.primaryFallback)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(AppColor.surface)
                    .frame(width: 120, height: 120)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                
                Image(systemName: selectedTab == .requests ? "person.badge.plus" : "bell.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColor.textSecondary.opacity(0.5), AppColor.textSecondary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .offset(y: -20)
            
            VStack(spacing: 8) {
                Text(selectedTab == .requests ? "İstek Yok" : "Bildirim Yok")
                    .font(AppFont.title3)
                    .foregroundColor(AppColor.textPrimary)
                
                Text(selectedTab == .requests ? "Bekleyen arkadaşlık isteği veya davet yok." : "Burada görecek bir şey yok.")
                    .font(AppFont.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var notificationsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(groupedNotifications, id: \.header) { group in
                    Section(header:
                        Text(group.header)
                            .font(AppFont.footnoteBold)
                            .foregroundColor(AppColor.textSecondary.opacity(0.8))
                            .padding(.horizontal, Spacing.md)
                            .padding(.bottom, 8)
                    ) {
                        ForEach(group.items) { notification in
                            NotificationRichRow(notification: notification)
                                .onTapGesture {
                                    handleNotificationTap(notification)
                                }
                        }
                    }
                }
            }
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .refreshable {
            await appState.notifications.refresh()
        }
    }

    // MARK: - Actions

    private func handleNotificationTap(_ notification: AppNotification) {
        // Mark as read
        Task { await appState.notifications.markAsRead(notification) }

        // Navigation
        switch notification.type {
        case .eventInvite, .eventInviteAccepted, .eventInviteDeclined, .eventReminder, .eventUpdate, .eventCancelled:
            if let eventId = notification.eventId {
                dismiss() // Close sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.deepLinkEventId = eventId
                }
            }

        case .postLike, .postComment, .commentReply, .postShare:
            if let postId = notification.postId {
                dismiss() // Close sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.deepLinkPostId = postId
                }
            }

        case .friendRequest, .friendRequestAccepted, .newFollower:
            if let userId = notification.fromUserId {
                dismiss() // Close sheet
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.presentUserProfile(userId: userId)
                }
            }

        case .storyReply, .storyReaction, .storyLike:
            // Navigate to chat with the user who reacted/replied
            if let userId = notification.fromUserId {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.selectedTab = .chat
                    // Could also deep link to specific chat thread if needed
                }
            }

        case .system:
            break
        }
    }
}

// MARK: - Rich Row View

struct NotificationRichRow: View {
    let notification: AppNotification
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
             // Unread Indicator
            if !notification.isRead {
                Circle()
                    .fill(AppColor.primaryFallback)
                    .frame(width: 8, height: 8)
            } 
            
            // Avatar with Badge
            avatarView
            
            // Text Content
            VStack(alignment: .leading, spacing: 4) {
                // Rich Text Construction
                Text(buildRichText())
                    .font(.system(size: 14))
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(notification.timeAgo)
                    .font(.caption2)
                    .foregroundColor(AppColor.textSecondary)
            }
            .layoutPriority(1)
            
            Spacer(minLength: 0)
            
            // Right Side Action / Preview
            rightSideContent
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // Make full row tappable
    }
    
    // MARK: - Avatar
    
    private var avatarView: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main Avatar
            if let urlStr = notification.fromUserAvatar, let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(AppColor.surface).overlay(ActivityIndicator())
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            } else {
                Circle() // Fallback
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(String(notification.fromUserName?.prefix(1) ?? "?"))
                            .font(AppFont.headline)
                            .foregroundColor(.orange)
                    )
            }
            
            // Badge Icon (Heart, Speech bubble, etc)
            ZStack {
                Circle()
                    .fill(AppColor.background)
                    .frame(width: 22, height: 22)
                
                Circle()
                    .fill(Color(hex: notification.iconColor))
                    .frame(width: 18, height: 18)
                
                Image(systemName: notification.iconName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColor.onPrimary)
            }
            .offset(x: 2, y: 2)
        }
    }
    
    // MARK: - Text Builder
    
    func buildRichText() -> AttributedString {
        let userName = notification.fromUserName ?? "Biri"
        var string = AttributedString(userName)
        string.font = .system(size: 15, weight: .bold)
        
        var actionText = AttributedString(" " + actionDescription)
        actionText.font = .system(size: 15, weight: .regular)
        
        string.append(actionText)
        return string
    }
    
    var actionDescription: String {
        switch notification.type {
        case .eventInvite: return "seni bir etkinliğe davet etti."
        case .eventInviteAccepted: return "etkinlik davetini kabul etti."
        case .postLike: return "gönderini beğendi."
        case .postComment: return "gönderine yorum yaptı: \"\(notification.body)\""
        case .postShare: return "gönderini paylaştı."
        case .friendRequest: return "sana arkadaşlık isteği gönderdi."
        case .friendRequestAccepted: return "arkadaşlık isteğini kabul etti."
        case .newFollower: return "seni takip etmeye başladı."
        case .eventReminder: return "etkinliğine az kaldı: \(notification.eventName ?? "")"
        case .eventUpdate: return "etkinlik güncellendi: \(notification.eventName ?? "")"
        case .eventCancelled: return "etkinlik iptal edildi: \(notification.eventName ?? "")"
        case .storyReply: return "hikayene yanıt verdi."
        case .storyReaction: return "hikayene \(notification.reactionEmoji ?? "😊") tepki verdi."
        case .storyLike: return "hikayeni beğendi."
        default: return notification.body
        }
    }
    
    // MARK: - Right Side
    
    @ViewBuilder
    var rightSideContent: some View {
        switch notification.type {
        case .eventInvite:
            if let eventId = notification.eventId {
                Button("Katıl") {
                    Task {
                        await appState.interactions.joinEvent(eventId: eventId)
                        await appState.notifications.markAsRead(notification)
                    }
                }
                .font(AppFont.footnoteBold)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppColor.primaryFallback)
                .foregroundColor(AppColor.onPrimary)
                .clipShape(Capsule())
                .shadow(color: AppColor.primaryFallback.opacity(0.3), radius: 5, y: 3)
            }
            
        case .friendRequest:
             // Onayla / Reddet (Mini)
             if let fromId = notification.fromUserId {
                 HStack(spacing: 8) {
                     Button("Onayla") {
                         Task {
                             await appState.friends.acceptRequest(fromUserId: fromId)
                             await appState.notifications.markAsRead(notification)
                         }
                     }
                     .font(AppFont.footnoteBold)
                     .padding(.horizontal, 14)
                     .padding(.vertical, 8)
                     .background(AppColor.primaryFallback)
                     .foregroundColor(AppColor.onPrimary)
                     .clipShape(Capsule())
                     
                     Button {
                         Task {
                            await appState.friends.rejectRequest(fromUserId: fromId)
                            await appState.notifications.deleteNotification(notification)
                         }
                     } label: {
                         Image(systemName: "xmark")
                             .font(.caption.bold())
                             .foregroundColor(AppColor.textSecondary)
                             .padding(8)
                             .background(AppColor.surface)
                             .clipShape(Circle())
                             .overlay(Circle().stroke(AppColor.border, lineWidth: 1))
                     }
                 }
             }
             
        case .postLike, .postComment, .postShare:
            if let _ = notification.postId {
                 RoundedRectangle(cornerRadius: 8)
                    .fill(AppColor.surface)
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "photo").foregroundColor(AppColor.textSecondary))
                    .shadow(color: Color.black.opacity(0.05), radius: 2)
            }

        default:
            EmptyView()
        }
    }
}

// Helper for ActivityIndicator since standard ProgressView can be large
struct ActivityIndicator: View {
    var body: some View {
        ProgressView().scaleEffect(0.6)
    }
}

#Preview {
    let session = SessionManager()
    let theme = AppThemeManager()
    let location = LocationManager()
    let appState = AppState(session: session, theme: theme, location: location)
    
    return NotificationsView()
        .environmentObject(appState)
}
