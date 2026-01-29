# Firebase Backend

## Overview

Semtio uses Firebase for:
- **Authentication** - Apple & Google Sign-In
- **Firestore** - NoSQL database
- **Cloud Functions** - Server-side logic
- **Cloud Storage** - Media files
- **Cloud Messaging** - Push notifications

## Project Configuration

```json
// .firebaserc
{
  "projects": {
    "default": "semtio"
  }
}
```

## Cloud Functions

Located at: `/Backend/Firebase/functions/`

### Deployment

```bash
cd Backend/Firebase/functions
npm install
npm run build
firebase deploy --only functions
```

### Available Functions (12 total)

| Function | Trigger | Description |
|----------|---------|-------------|
| `onUserCreate` | Auth onCreate | Initialize new user profile |
| `onUserUpdate` | Firestore onUpdate | Sync profile changes |
| `onUserDelete` | Auth onDelete | Clean up user data |
| `sendNotification` | HTTPS callable | Send push notification |
| `createEvent` | HTTPS callable | Create new event |
| `joinEvent` | HTTPS callable | Join an event |
| `leaveEvent` | HTTPS callable | Leave an event |
| `sendMessage` | HTTPS callable | Send chat message |
| `followUser` | HTTPS callable | Follow a user |
| `unfollowUser` | HTTPS callable | Unfollow a user |
| `likePost` | HTTPS callable | Like a post |
| `commentOnPost` | HTTPS callable | Add comment |

### Function Configuration

```json
// firebase.json
{
  "functions": [
    {
      "source": "Backend/Firebase/functions",
      "codebase": "default",
      "predeploy": ["npm --prefix \"$RESOURCE_DIR\" run build"]
    }
  ]
}
```

## Firestore Database

### Collections

```
/users/{userId}
/posts/{postId}
/events/{eventId}
/chats/{chatId}/messages/{messageId}
/notifications/{notificationId}
/follows/{followId}
```

### Security Rules

File: `/Backend/Firebase/firestore.rules`

Key rules:
- Users can only read/write their own profile
- Posts are readable by all, writable by owner
- Chat messages require participant membership

### Indexes

File: `/Backend/Firebase/firestore.indexes.json`

Composite indexes for:
- Feed queries (timestamp + visibility)
- Event filtering (date + location)
- Chat message ordering

## Cloud Storage

### Security Rules

File: `/Backend/Firebase/storage.rules`

- Authenticated users can upload to their folder
- Profile images: `/users/{userId}/profile/*`
- Post media: `/posts/{postId}/*`
- Event images: `/events/{eventId}/*`

## Deployment

### Deploy All
```bash
firebase deploy
```

### Deploy Specific
```bash
# Functions only
firebase deploy --only functions

# Rules only
firebase deploy --only firestore:rules,storage

# Specific function
firebase deploy --only functions:sendNotification
```

### Emulator (Local Development)
```bash
firebase emulators:start
```

## Environment

- **Region**: europe-west3
- **Node.js**: 22
- **TypeScript**: Enabled
