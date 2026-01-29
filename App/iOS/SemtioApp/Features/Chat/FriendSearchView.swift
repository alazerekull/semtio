//
//  FriendSearchView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct FriendSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var friendStore: FriendStore

    @State private var searchQuery: String = ""
    @State private var debounceTask: Task<Void, Never>?

    init(userStore: UserStore, notificationRepo: NotificationRepositoryProtocol) {
        #if canImport(FirebaseFirestore)
        _friendStore = StateObject(wrappedValue: FriendStore(
            repo: FirestoreFriendRepository(),
            notificationRepo: notificationRepo,
            userStore: userStore
        ))
        #else
        _friendStore = StateObject(wrappedValue: FriendStore(
            repo: MockFriendRepository(),
            notificationRepo: notificationRepo,
            userStore: userStore
        ))
        #endif
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar

                // Content
                if friendStore.isLoading {
                    loadingView
                } else if searchQuery.isEmpty {
                    emptyStateView
                } else if friendStore.searchResults.isEmpty {
                    noResultsView
                } else {
                    searchResultsList
                }
            }
            .navigationTitle("Arkadaş Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColor.textSecondary)
                .font(.system(size: 16))

            TextField("Kullanıcı ara...", text: $searchQuery)
                .font(AppFont.body)
                .foregroundColor(AppColor.textPrimary)
                .onChange(of: searchQuery) { _, newValue in
                    performDebouncedSearch(query: newValue)
                }

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    friendStore.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColor.textSecondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(AppColor.border, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Aranıyor...")
                .font(AppFont.subheadline)
                .foregroundColor(AppColor.textSecondary)
            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 60))
                .foregroundColor(AppColor.textSecondary.opacity(0.5))

            Text("Arkadaş Ara")
                .font(AppFont.headline)
                .foregroundColor(AppColor.textPrimary)

            Text("Kullanıcı adı veya isim girerek\narkadaş arayın")
                .font(AppFont.subheadline)
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 60))
                .foregroundColor(AppColor.textSecondary.opacity(0.5))

            Text("Sonuç Bulunamadı")
                .font(AppFont.headline)
                .foregroundColor(AppColor.textPrimary)

            Text("'\(searchQuery)' için\nhiçbir kullanıcı bulunamadı")
                .font(AppFont.subheadline)
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - Search Results List

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(friendStore.searchResults) { user in
                    FriendSearchResultRow(user: user, currentUserId: appState.auth.uid ?? "")
                        .environmentObject(friendStore)
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Debounced Search

    private func performDebouncedSearch(query: String) {
        debounceTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            friendStore.clearSearch()
            return
        }

        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            guard !Task.isCancelled else { return }

            await friendStore.search(query: query)
        }
    }
}

// MARK: - User Result Row

struct FriendSearchResultRow: View {
    let user: AppUser
    let currentUserId: String
    @EnvironmentObject var friendStore: FriendStore
    @State private var isSendingRequest = false
    @State private var requestSent = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarURL = user.avatarURL, !avatarURL.isEmpty {
                AsyncImage(url: URL(string: avatarURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(AppColor.surface)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(AppColor.textSecondary)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(AppColor.surface)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(AppColor.textSecondary)
                            .font(.system(size: 20))
                    )
            }

            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName)
                    .font(AppFont.headline)
                    .foregroundColor(AppColor.textPrimary)

                if let username = user.username {
                    Text("@\(username)")
                        .font(AppFont.subheadline)
                        .foregroundColor(AppColor.textSecondary)
                }

                if let district = user.district ?? user.city {
                    Text(district)
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.textSecondary)
                }
            }

            Spacer()

            // Action Button
            actionButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
    }

    @ViewBuilder
    private var actionButton: some View {
        if requestSent {
            // Request Sent Badge
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                Text("Gönderildi")
                    .font(AppFont.caption)
            }
            .foregroundColor(AppColor.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppColor.primary.opacity(0.1))
            )
        } else if isSendingRequest {
            // Loading
            ProgressView()
                .scaleEffect(0.8)
                .frame(width: 40, height: 32)
        } else {
            // Send Request Button
            Button {
                sendFriendRequest()
            } label: {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColor.onPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppColor.primary)
                    .clipShape(Capsule())
            }
        }
    }

    private func sendFriendRequest() {
        isSendingRequest = true

        Task {
            await friendStore.sendRequest(from: currentUserId, to: user.id)

            await MainActor.run {
                isSendingRequest = false
                requestSent = true

                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FriendSearchView(
        userStore: UserStore(repo: MockUserRepository()),
        notificationRepo: MockNotificationRepository()
    )
        .environmentObject(AppState(
            session: SessionManager(),
            theme: AppThemeManager(),
            location: LocationManager()
        ))
}
