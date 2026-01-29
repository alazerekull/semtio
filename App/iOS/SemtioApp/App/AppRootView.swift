//
//  AppRootView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

struct AppRootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var session: SessionManager
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var themeManager: AppThemeManager
    
    @State private var isSplashFinished = false
    @State private var lastInitializedUid: String? = nil
    
    var body: some View {
        Group {
            if !isSplashFinished {
                SplashView()
                    .task {
                        // Run bootstrap
                        await session.bootstrap()
                        // Ensure minimum delay
                        try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                        
                        withAnimation {
                            isSplashFinished = true
                        }
                    }
            } else {
                switch session.state {
                case .unknown:
                    // Fallback if bootstrap failed or is slow
                    ProgressView()
                case .signedOut:
                    LoginScreen()
                case .signedIn:
                    if !auth.isReady {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Bağlanılıyor...")
                                .foregroundColor(.gray)
                        }
                        .task {
                            auth.bootstrap()
                        }
                    } else if userStore.isProfileComplete {
                        MainTabView()
                            // Deep link event sheet
                            .sheet(item: deepLinkEventBinding) { eventId in
                                DeepLinkEventSheet(eventId: eventId)
                            }
                            // Deep link chat sheet
                            .sheet(item: deepLinkChatBinding) { threadId in
                                DeepLinkChatSheet(threadId: threadId)
                            }
                            // Deep link post sheet
                            .sheet(item: deepLinkPostBinding) { postId in
                                DeepLinkPostSheet(postId: postId)
                            }
                            // Deep link invite sheet
                            .sheet(item: deepLinkInviteBinding) { token in
                                DeepLinkInviteSheet(token: token)
                            }
                            // Public Profile Sheet
                            .sheet(item: publicProfileBinding) { userId in
                                PublicProfileView(userId: userId)
                            }
                            // Global CreateEventScreen sheet
                            .fullScreenCover(isPresented: $appState.isCreateEventPresented) {
                                CreateEventSheetWrapper(onCreated: {
                                    appState.onEventCreated()
                                })
                            }
                            // Global CreatePostScreen sheet
                            .fullScreenCover(isPresented: $appState.isCreatePostPresented) {
                                CreatePostScreen()
                            }
                            // Global PaywallView sheet
                            .sheet(isPresented: $appState.isPaywallPresented) {
                                PaywallView()
                                    .environmentObject(appState)
                            }
                            .onAppear {
                                // Consume all pending intents when user is ready
                                appState.consumeAllPendingIntents()
                            }
                    } else {
                        ProfileCompletionView()
                    }
                }
            }
        }
        .environmentObject(appState.userStore)
        .environmentObject(appState.events)
        .environmentObject(appState.location)
        .environmentObject(appState.friends)
        .environmentObject(appState.chat)
        .environmentObject(appState.auth)
        .environmentObject(appState.session)
        .environmentObject(appState.interactions)
        .environmentObject(appState.interactions)
        .environmentObject(appState.saved)
        .environmentObject(themeManager)
        .preferredColorScheme(themeManager.colorScheme)
        .animation(.easeInOut, value: appState.session.state)
        .onAppear {
            print("🎨 AppRootView themeManager:", ObjectIdentifier(themeManager))
        }
        .onOpenURL { url in
            appState.handleDeepLink(url)
        }
        .task {
            // WIRE UP GLOBAL AUTH LISTENER HERE
            // This satisfies "Ensure this runs reliably using FirebaseAuth.addStateDidChangeListener"
            // We bridge AuthManager -> UserStore here or inside AppState. 
            // Since AuthManager is in AppState, doing it here is safe.
            appState.auth.startAuthStateListener { user in
                if let user = user {
                    Task {
                        // GUARANTEED DOC CREATION
                        await appState.userStore.createUserDocIfMissing(
                            uid: user.uid,
                            email: user.email,
                            displayName: user.displayName
                        )
                        // Trigger init (idempotent)
                        await initializeUserData(uid: user.uid)
                    }
                }
            }
        }
        .onChangeCompatible(of: appState.auth.uid) { newUid in
            Task {
                if let uid = newUid {
                    UsageLimitService.shared.setUser(uid: uid)
                    PushTokenService.shared.setUser(uid: uid)
                    appState.postInteractions.setUser(uid: uid)
                    await appState.followInteractions.setUser(uid: uid)
                    await initializeUserData(uid: uid)
                } else {
                    UsageLimitService.shared.setUser(uid: nil)
                    PushTokenService.shared.setUser(uid: nil)
                    appState.postInteractions.setUser(uid: nil)
                    await appState.followInteractions.setUser(uid: nil)
                    appState.interactions.clearState()
                    appState.saved.clearState()
                    // Reset idempotency guard
                    lastInitializedUid = nil
                }
            }
        }
        .onChangeCompatible(of: userStore.isProfileComplete) { isComplete in
            if isComplete && session.state == .signedIn {
                appState.consumeAllPendingIntents()
            }
        }
    }
    
    // ... Deep Link Bindings ...
    private var deepLinkEventBinding: Binding<String?> {
        Binding(get: { appState.deepLinkEventId }, set: { if $0 == nil { appState.clearDeepLinkEvent() } })
    }
    private var deepLinkChatBinding: Binding<String?> {
        Binding(get: { appState.deepLinkChatThreadId }, set: { if $0 == nil { appState.clearDeepLinkChatThread() } })
    }
    private var deepLinkPostBinding: Binding<String?> {
        Binding(get: { appState.deepLinkPostId }, set: { if $0 == nil { appState.clearDeepLinkPost() } })
    }
    private var deepLinkInviteBinding: Binding<String?> {
        Binding(get: { appState.deepLinkInviteToken }, set: { if $0 == nil { appState.clearDeepLinkInvite() } })
    }
    private var publicProfileBinding: Binding<String?> {
        Binding(get: { appState.publicProfileUserId }, set: { if $0 == nil { appState.publicProfileUserId = nil } })
    }
    
    // MARK: - Initialization
    
    /// Initializes all user-related data when auth becomes ready (Idempotent)
    private func initializeUserData(uid: String) async {
        if lastInitializedUid == uid {
            return // Skip duplicate init
        }
        
        print("🟢 initializeUserData: Starting for \(uid)")
        lastInitializedUid = uid
        
        // Sync user profile
        await appState.userStore.syncAuthUser(
            uid: uid,
            email: appState.auth.email,
            displayName: appState.auth.displayName
        )
        
        // Initialize interaction stores
        await appState.interactions.setUser(uid: uid)
        await appState.saved.setUser(uid: uid)
        
        // Load Friends
        await appState.friends.loadFriends(userId: uid)
        
        print("🟢 initializeUserData: Completed for \(uid)")
        
        // REQUIREMENT: Run diagnostic immediately after login init
        // LOW-LEVEL DEBUG ONLY - DISABLES MOCK MODE ISOLATION
        // await FirestoreDiagnostic.debugUsersCollection()
    }
}

// MARK: - Create Event Sheet Wrapper

/// Wrapper for CreateEventScreen presented globally
struct CreateEventSheetWrapper: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    /// Called after successful event creation
    var onCreated: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            CreateEventScreen(onCreated: onCreated)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("İptal") {
                            appState.dismissCreateEvent()
                        }
                    }
                }
        }
        .environmentObject(appState)
        .environmentObject(appState.events)
        .environmentObject(appState.location)
        .environmentObject(appState.userStore)
    }
}

// MARK: - Deep Link Event Sheet

/// Sheet view that loads and displays event from deep link
struct DeepLinkEventSheet: View {
    let eventId: String
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var event: Event?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Etkinlik yükleniyor...")
                            .foregroundColor(.gray)
                    }
                } else if let event = event {
                    EventDetailScreen(event: event)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Etkinlik bulunamadı")
                            .font(.headline)
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Button("Kapat") {
                            dismiss()
                        }
                        .padding(.top)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadEvent()
        }
    }
    
    private func loadEvent() async {
        isLoading = true
        do {
            let events = try await appState.events.repo.fetchEvents()
            event = events.first { $0.id == eventId }
            if event == nil {
                errorMessage = "Bu etkinlik artık mevcut değil."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Deep Link Chat Sheet

/// Sheet view for navigating to chat thread from deep link/push notification
struct DeepLinkChatSheet: View {
    let threadId: String
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ChatScreen(threadId: threadId)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Kapat") {
                            dismiss()
                        }
                    }
                }
        }
        .environmentObject(appState)
        .environmentObject(appState.chat)
        .environmentObject(appState.userStore)
        .onAppear {
            // Mark thread as read when opened via deep link
            if let uid = appState.auth.uid {
                Task {
                    await appState.chat.markThreadRead(threadId: threadId, userId: uid)
                }
            }
        }
    }
}



// MARK: - Deep Link Invite Sheet

struct DeepLinkInviteSheet: View {
    let token: String
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView()
                    Text("Davet kontrol ediliyor...")
                } else if let error = error {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Davet Hatası")
                        .font(.headline)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppColor.textSecondary)
                        .padding()
                    
                    Button("Kapat") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("Başarıyla Katıldınız!")
                        .font(.headline)
                }
            }
            .navigationTitle("Davet")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            // Process invite
            do {
                let eventId = try await appState.events.repo.joinWithInvite(token: token)
                
                // Success
                isLoading = false
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Brief showing success
                
                dismiss() // Close invite sheet
                
                // Navigate to event
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    appState.deepLinkEventId = eventId
                }
                
            } catch {
                isLoading = false
                self.error = error.localizedDescription
            }
        }
    }
}

// MARK: - String Identifiable Extension

extension String: @retroactive Identifiable {
    public var id: String { self }
}
