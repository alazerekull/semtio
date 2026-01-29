//
//  AppState.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    let session: SessionManager
    let theme: AppThemeManager
    let userStore: UserStore
    let events: EventStore
    let feed: FeedStore
    let interactions: EventInteractionStore
    let saved: SavedEventsStore
    let subscription: SubscriptionStore
    let usageLimit: UsageLimitService
    let location: LocationManager
    let friends: FriendStore
    let chat: ChatStore
    let auth: AuthManager
    let appearance: AppearanceManager
    let accountService: AccountServiceProtocol
    let announcementRepo: AnnouncementRepositoryProtocol
    let posts: PostRepositoryProtocol
    let postFeed: PostFeedStore // Store for UI state

    let postInteractions: PostInteractionStore
    let followInteractions: FollowInteractionStore
    let notificationRepo: NotificationRepositoryProtocol // Now exposed
    let notifications: NotificationStore
    let stories: StoryStore
    let deepLink: DeepLinkService
    
    @Published var isTabBarHidden = false
    @Published var selectedTab: AppTab = .home
    
    /// Pending deep link destination (stored until user is authenticated + profile complete)
    @Published var pendingDestination: DeepLinkDestination = .none

    /// Signals for programmatic navigation within the Profile tab
    @Published var profileTabToSelect: ProfileViewModel.ProfileTab? = nil
    @Published var savedTabToSelect: ProfileViewModel.SavedTab? = nil
    
    /// Event to show via deep link navigation
    @Published var deepLinkEventId: String? = nil
    
    /// Chat thread to show via deep link/push navigation
    @Published var deepLinkChatThreadId: String? = nil
    
    /// Post to show via deep link/push navigation
    @Published var deepLinkPostId: String? = nil
    @Published var deepLinkPostOwnerId: String? = nil
    @Published var deepLinkPostUsername: String? = nil
    
    /// Invite token to process
    @Published var deepLinkInviteToken: String? = nil
    
    /// Signal for post deletion (to update UI across screens)
    @Published var lastDeletedPostId: String? = nil
    
    /// Signal for saved posts change (to refresh saved lists)
    @Published var savedPostsChanged: Bool = false
    
    /// Signal for new post creation (to refresh profile posts grid)
    @Published var postsChanged: Bool = false
    
    /// User ID for the public profile sheet
    @Published var publicProfileUserId: String? = nil
    
    // MARK: - Create Event State
    
    /// Controls global presentation of CreateEventScreen
    @Published var isCreateEventPresented: Bool = false
    
    /// Controls global presentation of PaywallView
    @Published var isPaywallPresented: Bool = false
    
    /// Pending create intent (stored until user is authenticated + profile complete)
    @Published var pendingCreateIntent: Bool = false
    
    @MainActor
    init(session: SessionManager,
         theme: AppThemeManager,
         location: LocationManager) {
        self.session = session
        self.theme = theme
        self.location = location
        self.usageLimit = UsageLimitService.shared
        
        // 🔌 CENTRALIZED DATA SOURCE SWITCH
        // All repositories are created via RepositoryFactory
        // Change AppConfig.dataSource to switch between mock and Firestore
        let eventRepo = RepositoryFactory.makeEventRepository()
        let userRepo = RepositoryFactory.makeUserRepository()
        
        self.userStore = UserStore(repo: userRepo)
        self.events = EventStore(repo: eventRepo)
        self.feed = FeedStore(repo: eventRepo)
        self.interactions = EventInteractionStore(repo: eventRepo)
        self.saved = SavedEventsStore(repo: userRepo)
        self.subscription = SubscriptionStore()
        self.chat = ChatStore(repo: RepositoryFactory.makeChatRepository())
        self.notificationRepo = RepositoryFactory.makeNotificationRepository()
        self.friends = FriendStore(repo: RepositoryFactory.makeFriendRepository(), notificationRepo: self.notificationRepo, userStore: self.userStore)
        self.announcementRepo = RepositoryFactory.makeAnnouncementRepository()
        let postsRepo = RepositoryFactory.makePostRepository()
        self.posts = postsRepo
        self.postFeed = PostFeedStore(repo: postsRepo, moderationRepo: FirestoreModerationRepository())
        self.postInteractions = PostInteractionStore(repo: postsRepo, notificationRepo: notificationRepo, userStore: self.userStore)
        self.followInteractions = FollowInteractionStore(repo: RepositoryFactory.makeFollowRepository())
        self.notifications = NotificationStore(repo: notificationRepo)
        
        // Stories (fetches from both friends AND following users)
        let followRepo = RepositoryFactory.makeFollowRepository()
        self.stories = StoryStore(repo: FirestoreStoryRepository(), userStore: self.userStore, followRepo: followRepo)
        
        self.auth = AuthManager()
        self.appearance = AppearanceManager()
        self.deepLink = DeepLinkService()
        
        // Account service based on data source
        switch AppConfig.dataSource {
        case .mock:
            self.accountService = MockAccountService()
        case .firestore:
            self.accountService = DefaultAccountService()
        }
        
        // Inject dependencies
        self.session.auth = self.auth
        
        // SYNC USER ON LOGIN
        self.auth.$uid
            .dropFirst() // Skip initial value
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] uid in
                guard let self = self, let uid = uid else { return }
                print("🔄 AppState: Auth UID changed to \(uid), triggering sync...")
                Task {
                    // Fetch real auth data if possible
                    let email = self.auth.email
                    let name = self.auth.displayName
                    await self.userStore.syncAuthUser(uid: uid, email: email, displayName: name)
                }
            }
            .store(in: &self.session.cancellables) // Store in session manager's cancellables or our own

        
        // Start StoreKit transaction listener
        subscription.startListening()
        
        if AppConfig.isDebugMode {
            print("📦 AppState initialized with dataSource: \(AppConfig.dataSource)")
        }
    }
    
    // MARK: - Paywall Actions
    
    /// Presents PaywallView
    func presentPaywall() {
        isPaywallPresented = true
        print("💎 AppState: Presenting Paywall")
    }
    
    /// Dismisses PaywallView
    func dismissPaywall() {
        isPaywallPresented = false
    }
    
    // MARK: - Create Event Actions
    
    /// Presents CreateEventScreen if user is ready and has usage quota, otherwise shows paywall or stores intent
    func presentCreateEvent() {
        // Not authenticated or profile incomplete -> store pending intent
        guard isUserReady else {
            pendingCreateIntent = true
            print("➕ AppState: Stored pending create intent (user not ready)")
            return
        }
        
        // Check usage limit
        if usageLimit.canCreateEvent(isPremium: subscription.isPremium) {
            isCreateEventPresented = true
            print("➕ AppState: Presenting CreateEventScreen")
        } else {
            // Limit reached -> show paywall
            presentPaywall()
            print("➕ AppState: Usage limit reached, presenting paywall")
        }
    }
    
    /// Dismisses CreateEventScreen
    func dismissCreateEvent() {
        isCreateEventPresented = false
    }
    
    /// Called after successful event creation to record usage
    func onEventCreated() {
        usageLimit.recordEventCreated()
        dismissCreateEvent()
        
        // Refresh feed to show new event
        Task {
            await feed.refresh()
        }
    }
    
    /// Consumes pending create intent after user becomes ready
    func consumePendingCreateIntent() {
        guard pendingCreateIntent else { return }
        pendingCreateIntent = false
        
        // Re-run the full check (including usage limit)
        presentCreateEvent()
        print("➕ AppState: Consuming pending create intent")
    }
    
    // MARK: - Create Post Actions
    
    /// Controls global presentation of CreatePostScreen
    @Published var isCreatePostPresented: Bool = false
    
    /// Pending create post intent
    @Published var pendingCreatePostIntent: Bool = false
    
    /// Presents CreatePostScreen if user is ready, otherwise stores intent
    func presentCreatePost() {
        // Must be signed in and complete
        guard isUserReady else {
            pendingCreatePostIntent = true
            print("📝 AppState: Stored pending create post intent (user not ready)")
            return
        }
        
        isCreatePostPresented = true
        print("📝 AppState: Presenting CreatePostScreen")
    }
    
    /// Dismisses CreatePostScreen
    func dismissCreatePost() {
        isCreatePostPresented = false
    }
    
    /// Consumes pending create post intent after user becomes ready
    func consumePendingCreatePostIntentIfNeeded() {
        guard pendingCreatePostIntent else { return }
        pendingCreatePostIntent = false
        
        presentCreatePost()
        print("📝 AppState: Consuming pending create post intent")
    }
    
    /// Checks if user is signed in and profile is complete
    var isUserReady: Bool {
        session.state == .signedIn && userStore.isProfileComplete
    }
    
    // MARK: - Deep Link Handling
    
    /// Handles an incoming deep link URL
    func handleDeepLink(_ url: URL) {
        let destination = deepLink.parse(url)
        handleDestination(destination)
    }
    
    /// Handles a push notification payload
    func handleNotification(_ userInfo: [AnyHashable: Any]) {
        let destination = deepLink.parseNotification(userInfo)
        handleDestination(destination)
    }
    
    /// Common handler for all destination types
    private func handleDestination(_ destination: DeepLinkDestination) {
        guard destination != .none else { return }
        
        // If user is ready, navigate immediately
        if isUserReady {
            navigateToDestination(destination)
        } else {
            // Store for later
            pendingDestination = destination
            print("🔗 AppState: Stored pending destination: \(destination)")
        }
    }
    
    /// Consumes pending destination and navigates
    func consumePendingDestination() {
        guard pendingDestination != .none else { return }
        
        navigateToDestination(pendingDestination)
        pendingDestination = .none
    }
    
    /// Consumes all pending intents (deep links + create intent)
    func consumeAllPendingIntents() {
        consumePendingDestination()
        consumePendingCreateIntent()
        consumePendingCreatePostIntentIfNeeded()
    }
    
    /// Presents a user profile (Public or Own)
    func presentUserProfile(userId: String) {
        if let currentUid = auth.uid, currentUid == userId {
            // If it's the current user, switch to Profile tab
            selectedTab = .profile
        } else {
            // Show public profile sheet
            publicProfileUserId = userId
        }
    }
    
    /// Navigate to a deep link destination
    private func navigateToDestination(_ destination: DeepLinkDestination) {
        switch destination {
        case .eventDetail(let eventId):
            deepLinkEventId = eventId
            print("🔗 AppState: Navigating to event: \(eventId)")
            
        case .chat(let threadId):
            deepLinkChatThreadId = threadId
            // Also switch to chat tab for better UX
            selectedTab = .chat
            print("🔗 AppState: Navigating to chat thread: \(threadId)")
            
        case .userProfile(let userId):
            presentUserProfile(userId: userId)
            print("🔗 AppState: Navigating to user profile: \(userId)")
            
        case .post(let postId, let ownerId, let username):
            deepLinkPostId = postId
            deepLinkPostOwnerId = ownerId
            deepLinkPostUsername = username
            print("🔗 AppState: Navigating to post: \(postId) (owner: \(ownerId ?? "unknown") user: \(username ?? "unknown"))")
            
        case .invite(let token):
            deepLinkInviteToken = token
            print("🔗 AppState: Processing invite token")
            
        case .none:
            break
        }
    }
    
    /// Clears deep link event after navigation
    func clearDeepLinkEvent() {
        deepLinkEventId = nil
    }
    
    /// Clears deep link chat thread after navigation
    func clearDeepLinkChatThread() {
        deepLinkChatThreadId = nil
    }
    
    /// Clears deep link post after navigation
    func clearDeepLinkPost() {
        deepLinkPostId = nil
        deepLinkPostOwnerId = nil
        deepLinkPostUsername = nil
    }
    
    /// Clears deep link invite token
    func clearDeepLinkInvite() {
        deepLinkInviteToken = nil
    }
}
