//
//  CustomTabBar.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

enum AppTab: String, CaseIterable {
    case home = "house.fill"
    case events = "calendar"
    case map = "map.fill"
    case chat = "bubble.left.and.bubble.right.fill"
    case profile = "person.fill"
    
    var title: String {
        switch self {
        case .home: return "Ana Sayfa"
        case .events: return "Etkinlikler"
        case .map: return "Harita"
        case .chat: return "Sohbet"
        case .profile: return "Profil"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button(action: {
                    if selectedTab == tab {
                        // Notify parent to reset stack if needed
                        NotificationCenter.default.post(name: NSNotification.Name("ResetTab"), object: tab)
                    } else {
                        withAnimation(.spring()) {
                            selectedTab = tab
                        }
                    }
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            Image(systemName: tab.rawValue)
                            .font(AppFont.title2)
                            .frame(height: 24) // baseline stabilize
                            .foregroundColor(selectedTab == tab ? AppColor.textPrimary : AppColor.textSecondary)
                        
                        // Active Green Dot
                        if selectedTab == tab {
                            Circle()
                                .fill(Color.semtioGreen)
                                .frame(width: 8, height: 8)
                                .offset(x: 10, y: -10)
                        }
                        
                        // Unread Badge for Chat tab
                        if tab == .chat {
                            UnreadBadge(count: appState.chat.totalUnread)
                                .offset(x: 12, y: -12)
                        }
                    }
                    
                    Text(tab.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(selectedTab == tab ? .semtioPrimary : AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    .padding(.vertical, 14)
    .padding(.horizontal, 20)
    .background(AppColor.surface)
    .cornerRadius(40)
    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    .padding(.horizontal, 24)
    .padding(.bottom, 10)
}
}

// MARK: - Unread Badge

struct UnreadBadge: View {
    let count: Int
    
    var body: some View {
        Group {
            if count > 0 {
                Text(badgeText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColor.onPrimary)
                    .padding(.horizontal, count > 9 ? 4 : 0)
                    .frame(minWidth: 16, minHeight: 16)
                    .background(Circle().fill(Color.red))
            }
        }
    }
    
    private var badgeText: String {
        if count > 99 {
            return "99+"
        }
        return "\(count)"
    }
}
