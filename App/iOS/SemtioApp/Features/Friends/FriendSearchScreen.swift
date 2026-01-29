//
//  FriendSearchScreen.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct FriendSearchScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userStore: UserStore
    @StateObject private var viewModel = FriendSearchViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            searchBar
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.md)
            
            // Content
            contentView
        }
        .background(AppColor.background)
        .navigationTitle("Keşfet")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Run Firestore environment diagnostic on search screen open
            await FirestoreDiagnostic.runDiagnostic()
            
            // Configure ViewModel with FriendStore and UserStore
            viewModel.configure(
                friendStore: appState.friends,
                userStore: appState.userStore,
                currentUserId: userStore.currentUser.id
            )
            await viewModel.loadData()
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColor.textSecondary)
                .font(AppFont.headline)
            
            TextField("Arkadaş veya Etkinlik ara...", text: $viewModel.searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(AppFont.callout)
                .foregroundColor(AppColor.textPrimary)
                .onChange(of: viewModel.searchQuery) { _, newValue in
                    viewModel.onSearchQueryChanged(newValue)
                }
            
            if !viewModel.searchQuery.isEmpty {
                Button(action: { 
                    viewModel.searchQuery = ""
                    viewModel.searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColor.textSecondary)
                        .font(AppFont.headline)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground)) // Slightly darker/distinct background
        .cornerRadius(Radius.lg)
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        if !viewModel.isConfigured {
            Spacer()
            ProgressView()
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    
                    // 1. Suggested Users (Discover) - Only show if not searching or if search is empty
                    if !viewModel.isSearching && viewModel.searchQuery.isEmpty && !viewModel.suggestedUsers.isEmpty {
                        suggestedUsersSection
                    }
                    
                    // 2. Search Results
                    if viewModel.isSearching {
                        VStack(spacing: Spacing.md) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .padding(.top, Spacing.xl)
                            Text("Aranıyor...")
                                .font(AppFont.body)
                                .foregroundColor(AppColor.textSecondary)
                        }
                    } else if !viewModel.searchResults.isEmpty {
                        searchResultsSection
                    } else if !viewModel.searchQuery.isEmpty {
                        emptySearchState
                    }
                }
                .padding(.bottom, Spacing.xl)
            }
        }
    }
    
    // MARK: - Sections
    
    private var suggestedUsersSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Önerilen Kişiler")
                .font(AppFont.headline)
                .foregroundColor(AppColor.textPrimary)
                .padding(.horizontal, Spacing.md)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(viewModel.suggestedUsers) { user in
                        SuggestedUserCardLarge(
                            user: user,
                            relationship: viewModel.relationship(for: user.id),
                            onAdd: { Task { await viewModel.sendRequest(to: user.id) } },
                            onAccept: { Task { await viewModel.acceptRequest(from: user.id) } },
                            onReject: { Task { await viewModel.rejectRequest(from: user.id) } }
                        )
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
        .padding(.top, Spacing.md)
    }
    
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Sonuçlar")
                .font(AppFont.subheadline)
                .foregroundColor(AppColor.textSecondary)
                .padding(.horizontal, Spacing.md)
            
            LazyVStack(spacing: Spacing.sm) {
                ForEach(viewModel.searchResults) { user in
                    UserResultRow(
                        user: user,
                        relationship: viewModel.relationship(for: user.id),
                        onAdd: { Task { await viewModel.sendRequest(to: user.id) } },
                        onAccept: { Task { await viewModel.acceptRequest(from: user.id) } },
                        onReject: { Task { await viewModel.rejectRequest(from: user.id) } }
                    )
                }
            }
        }
    }
    
    private var emptySearchState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(AppColor.textSecondary.opacity(0.5))
                .padding(.top, Spacing.xl)
            
            Text("Sonuç Bulunamadı")
                .font(.headline)
                .foregroundColor(AppColor.textPrimary)
            
            Text("'\(viewModel.searchQuery)' için sonuç bulunamadı.\nFarklı bir arama yapmayı deneyin.")
                .font(.subheadline)
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
    }
}

// MARK: - Components

struct SuggestedUserCardLarge: View {
    let user: AppUser
    let relationship: UserRelationship
    let onAdd: () -> Void
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                     .fill(AppColor.surface)
                     .frame(width: 80, height: 80)
                     .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                
                if let avatarURL = user.avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        initialsView
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    initialsView
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                }
            }
            
            // Info
            VStack(spacing: 2) {
                Text(user.fullName)
                    .font(AppFont.calloutBold)
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)
                
                if let username = user.username {
                    Text("@\(username)")
                        .font(AppFont.footnote)
                        .foregroundColor(AppColor.textSecondary)
                        .lineLimit(1)
                }
            }
            
            // Action Button
            Group {
                switch relationship {
                case .none:
                    Button(action: onAdd) {
                        Text("Takip Et")
                            .font(AppFont.footnoteBold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [AppColor.primaryFallback, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(Radius.pill)
                    }
                    
                case .pendingOutgoing:
                    Button(action: {}) {
                        Text("İstek Gönderildi")
                            .font(AppFont.footnoteBold)
                            .foregroundColor(AppColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(Radius.pill)
                    }
                    .disabled(true)
                    
                case .friend:
                    Button(action: {}) {
                        Text("Arkadaşsınız")
                            .font(AppFont.footnoteBold)
                            .foregroundColor(AppColor.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .overlay(Capsule().stroke(AppColor.primary, lineWidth: 1))
                    }
                    .disabled(true)
                    
                case .pendingIncoming:
                    HStack(spacing: 8) {
                        Button(action: onAccept) {
                            Text("Kabul")
                                .font(AppFont.captionBold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(AppColor.primaryFallback)
                                .cornerRadius(Radius.pill)
                        }
                        
                        Button(action: onReject) {
                            Image(systemName: "xmark")
                                .font(AppFont.captionBold)
                                .foregroundColor(AppColor.textSecondary)
                                .padding(8)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
        .padding(Spacing.md)
        .frame(width: 160)
        .background(AppColor.surface)
        .cornerRadius(Radius.lg)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var initialsView: some View {
        ZStack {
            AppColor.primaryFallback.opacity(0.1)
            Text(String(user.fullName.prefix(1)).uppercased())
                .font(AppFont.largeTitle)
                .foregroundColor(AppColor.primaryFallback)
        }
    }
}

struct UserResultRow: View {
    let user: AppUser
    let relationship: UserRelationship
    let onAdd: () -> Void
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar with Status Dot
            ZStack(alignment: .bottomTrailing) {
                if let avatarURL = user.avatarURL, !avatarURL.isEmpty, let url = URL(string: avatarURL) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        initialsView
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    initialsView
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                }
                
                // Active Status Indicator (Mock for now, or based on presence)
                if relationship == .friend {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(AppColor.surface, lineWidth: 2))
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName)
                    .font(AppFont.callout)
                    .foregroundColor(AppColor.textPrimary)
                
                HStack(spacing: 4) {
                    if let username = user.username {
                        Text("@\(username)")
                            .font(.system(size: 14))
                            .foregroundColor(AppColor.textSecondary)
                    }
                    
                    if let city = user.city {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(AppColor.textSecondary)
                        Text(city)
                            .font(.system(size: 14))
                            .foregroundColor(AppColor.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            // Action Button
            switch relationship {
            case .none:
                Button(action: onAdd) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            LinearGradient(
                                colors: [AppColor.primaryFallback, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Circle())
                }
                
            case .pendingOutgoing:
                Button(action: {}) {
                    Image(systemName: "clock")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColor.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(Circle())
                }
                .disabled(true)
                
            case .friend:
                Button(action: {}) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColor.primary)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(AppColor.primary, lineWidth: 1))
                }
                .disabled(true)
                
            case .pendingIncoming:
                HStack(spacing: 12) {
                    Button(action: onReject) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColor.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(Circle())
                    }
                    
                    Button(action: onAccept) {
                        Text("Kabul")
                            .font(AppFont.captionBold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppColor.primaryFallback)
                            .cornerRadius(Radius.pill)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(AppColor.surface)
    }
    
    private var initialsView: some View {
        ZStack {
            AppColor.primaryFallback.opacity(0.1)
            Text(String(user.fullName.prefix(1)).uppercased())
                .font(AppFont.title3)
                .foregroundColor(AppColor.primaryFallback)
        }
    }
}

#Preview {
    let session = SessionManager()
    let theme = AppThemeManager()
    let location = LocationManager()
    let appState = AppState(session: session, theme: theme, location: location)
    
    return NavigationStack {
        FriendSearchScreen()
            .environmentObject(appState)
            .environmentObject(appState.userStore)
    }
}
