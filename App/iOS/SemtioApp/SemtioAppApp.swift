//
//  SemtioAppApp.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
@MainActor
struct SemtioAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState: AppState
    
    init() {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
        
        let session = SessionManager()
        let theme = AppThemeManager()
        let location = LocationManager()
        
        // Initialize AppState on MainActor to satisfy concurrency requirements
        // App launch happens on main thread, so assumeIsolated is safe here.
        let state = MainActor.assumeIsolated {
            AppState(session: session, theme: theme, location: location)
        }
        _appState = StateObject(wrappedValue: state)
    }
    @StateObject private var deepLinkService = DeepLinkService()
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appState)
                .environmentObject(appState.session)
                .environmentObject(appState.auth)
                .environmentObject(appState.userStore)
                .environmentObject(appState.theme)
                .environmentObject(appState.stories)
                .environmentObject(appState.chat)
                .environmentObject(appState.events)

                .environmentObject(deepLinkService)

                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    if GIDSignIn.sharedInstance.handle(url) {
                        return
                    }
                    #endif
                    deepLinkService.handle(url)
                }
                .onAppear {
                    // Wire AppDelegate to AppState for notification routing
                    appDelegate.appState = appState
                }
        }
    }
}
