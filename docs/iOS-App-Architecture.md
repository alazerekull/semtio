# iOS App Architecture

## Overview

Semtio uses a **Clean Architecture** pattern with SwiftUI and Combine.

```
┌─────────────────────────────────────────────┐
│                   Views                      │
│            (SwiftUI Views)                   │
├─────────────────────────────────────────────┤
│                  Stores                      │
│    (UserStore, ChatStore, EventStore)        │
├─────────────────────────────────────────────┤
│               Repositories                   │
│   (FirestoreUserRepository, MockRepo, etc.)  │
├─────────────────────────────────────────────┤
│                 Firebase                     │
│    (Firestore, Auth, Storage, Functions)     │
└─────────────────────────────────────────────┘
```

## Key Components

### 1. App Entry (`SemtioAppApp.swift`)

```swift
@main
struct SemtioAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appState)
                .environmentObject(appState.userStore)
                // ... other environment objects
        }
    }
}
```

### 2. State Management

**AppState** - Central state container:
- `userStore: UserStore` - User data & auth
- `chatStore: ChatStore` - Messaging
- `eventStore: EventStore` - Events
- `notificationStore: NotificationStore` - Notifications

### 3. Repository Pattern

```swift
// Protocol
protocol UserRepository {
    func getUser(id: String) async throws -> User
    func updateUser(_ user: User) async throws
}

// Firestore Implementation
class FirestoreUserRepository: UserRepository { ... }

// Mock Implementation (for previews/testing)
class MockUserRepository: UserRepository { ... }

// Cached Implementation (decorator)
class CachedUserRepository: UserRepository { ... }
```

**RepositoryFactory** creates repositories based on config:
```swift
if AppConfig.useMockRepositories {
    return MockUserRepository()
} else {
    return CachedUserRepository(upstream: FirestoreUserRepository())
}
```

### 4. Navigation

Uses SwiftUI's native navigation:
- `NavigationStack` for hierarchical navigation
- `@Environment(\.dismiss)` for dismissal
- Sheets for modal presentation

### 5. Design System

Centralized design tokens:
- `SemtioColors` - Brand colors
- `SemtioTypography` - Text styles
- `SemtioSpacing` - Layout spacing

## Dependencies

### Swift Package Manager

| Package | Version | Purpose |
|---------|---------|---------|
| Firebase iOS SDK | 11.0+ | Backend services |
| GoogleSignIn | 9.1+ | Google authentication |

## Build Configuration

| Setting | Value |
|---------|-------|
| iOS Deployment Target | 17.0 |
| Swift Version | 5.0 |
| Bundle ID | `com.alazonforce.semtio` |

## File Organization

The project uses **Xcode 16+ File System Synchronization**:
- Source files sync automatically with the file system
- No manual Xcode project file management needed
- Deleting a file removes it from the build automatically
