# Project Structure

## Directory Layout

```
SemtioProject/
├── App/
│   └── iOS/
│       ├── SemtioApp.xcodeproj/     # Xcode project
│       ├── SemtioApp.xcworkspace/   # Xcode workspace
│       ├── SemtioApp/               # Source code
│       │   ├── App/                 # App lifecycle & routing
│       │   ├── Core/                # Core framework
│       │   ├── Features/            # Feature modules
│       │   ├── SharedUI/            # Reusable UI components
│       │   └── Assets.xcassets/     # Images & colors
│       └── GoogleService-Info.plist # Firebase config
│
├── Backend/
│   └── Firebase/
│       ├── functions/
│       │   ├── src/index.ts         # Cloud Functions (12 functions)
│       │   ├── package.json
│       │   └── tsconfig.json
│       ├── firestore.rules          # Security rules
│       ├── firestore.indexes.json   # Database indexes
│       └── storage.rules            # Storage security
│
├── firebase.json                    # Firebase config
├── .firebaserc                      # Firebase project alias
└── .gitignore
```

## iOS App Structure

### `/App/iOS/SemtioApp/`

| Directory | Purpose | File Count |
|-----------|---------|------------|
| `App/` | App entry, routing, state | 8 files |
| `Core/` | Services, models, data layer | ~80 files |
| `Features/` | Feature-specific screens | ~150 files |
| `SharedUI/` | Reusable components | ~20 files |
| `Assets.xcassets/` | Images, colors | - |

### Core Layer (`/Core/`)

```
Core/
├── Data/           # Repositories (Firestore + Mock)
│   ├── User/
│   ├── Posts/
│   ├── Chat/
│   ├── Events/
│   ├── Feed/
│   └── ...
├── Models/         # Data models
├── Services/       # Business logic services
├── State/          # State managers (UserStore, etc.)
├── Networking/     # Network layer
├── DesignSystem/   # Design tokens
├── Security/       # Security utilities
└── Helpers/        # Utilities
```

### Features Layer (`/Features/`)

```
Features/
├── Auth/           # Login, registration
├── Home/           # Home feed
├── Profile/        # User profile, settings
├── Chat/           # Messaging
├── Events/         # Event discovery & creation
├── Map/            # Map-based features
├── Search/         # Search functionality
├── Notifications/  # Push notifications
└── ...
```

## Firebase Backend Structure

### Cloud Functions (`/Backend/Firebase/functions/`)

12 deployed functions:
- `onUserCreate` - New user setup
- `onUserUpdate` - Profile sync
- `onUserDelete` - User cleanup
- `sendNotification` - Push notifications
- `createEvent` - Event creation
- `joinEvent` - Event participation
- `leaveEvent` - Leave event
- `sendMessage` - Chat messaging
- `followUser` - Follow system
- `unfollowUser` - Unfollow
- `likePost` - Post likes
- `commentOnPost` - Comments

### Security Rules

- **Firestore Rules**: User-based access control
- **Storage Rules**: Authenticated uploads only
