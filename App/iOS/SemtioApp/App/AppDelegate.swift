//
//  AppDelegate.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import UIKit
import UserNotifications
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    
    /// Reference to AppState for notification routing (set by SemtioApp)
    weak var appState: AppState? {
        didSet {
            flushPendingNotification()
        }
    }
    
    /// Stored notification payload if AppState wasn't ready yet
    private var pendingNotificationUserInfo: [AnyHashable: Any]?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebase is configured in SemtioAppApp.init()
        
        #if canImport(FirebaseMessaging)
        // Set messaging delegate
        Messaging.messaging().delegate = self
        #endif
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permission
        requestNotificationPermission(application)
        
        // Handle notification if app was launched from terminated state
        // Note: usage of launchOptions?[.remoteNotification] is deprecated.
        // Modern iOS delivers this via UNUserNotificationCenter delegate even for launch IF the delegate is set early enough.
        // Or we can rely on proper handling. 
        // For now, silencing the specific warning or removing if redundant.
        // Since we set UNDelegate, we rely on it.
        /*
        if let remoteNotification = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [AnyHashable: Any] {
            print("📱 App launched from notification: \(remoteNotification)")
            // Route or buffer immediately
            routeNotification(remoteNotification)
        }
        */
        
        return true
    }
    
    // MARK: - Notification Permission
    
    private func requestNotificationPermission(_ application: UIApplication) {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                print("❌ Notification permission error: \(error)")
                return
            }
            
            if granted {
                print("✅ Notification permission granted")
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else {
                print("⚠️ Notification permission denied")
            }
        }
    }
    
    // MARK: - APNs Token Registration
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 APNs device token: \(tokenString)")
        
        #if canImport(FirebaseMessaging)
        // Pass APNs token to Firebase
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - Notification Routing
    
    private func routeNotification(_ userInfo: [AnyHashable: Any]) {
        // If appState is ready, handle immediately
        if let appState = appState {
            Task { @MainActor in
                appState.handleNotification(userInfo)
            }
        } else {
            // Buffer for later
            print("⏳ AppDelegate: Buffering notification (AppState not ready)")
            pendingNotificationUserInfo = userInfo
        }
    }
    
    private func flushPendingNotification() {
        guard let userInfo = pendingNotificationUserInfo,
              let appState = appState else { return }
        
        print("🚀 AppDelegate: Flushing buffered notification")
        Task { @MainActor in
            appState.handleNotification(userInfo)
            self.pendingNotificationUserInfo = nil
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    // Handle foreground notifications
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap (app in background or foreground)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("📱 Notification tapped: \(userInfo)")
        
        // Route to appropriate destination
        routeNotification(userInfo)
        
        completionHandler()
    }
}

// MARK: - MessagingDelegate

#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else {
            print("⚠️ FCM token is nil")
            return
        }
        
        print("📱 FCM token received: \(token.prefix(20))...")
        
        // Update PushTokenService
        PushTokenService.shared.updateToken(token)
        
        // Post notification for any other listeners
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: ["token": token]
        )
    }
}
#endif

// MARK: - Debug Testing
/*
 To test push notification routing in debug:
 
 // In any view's onAppear or button action:
 let testPayload: [AnyHashable: Any] = [
     "type": "chat",
     "threadId": "thread1"
 ]
 appState.handleNotification(testPayload)
 */
