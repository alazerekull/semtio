# Firebase Cloud Functions for Semtio

This directory contains Firebase Cloud Functions for the Semtio app.

## Functions

### `onNewChatMessage`
- **Trigger**: Firestore `onCreate` on `chats/{threadId}/messages/{msgId}`
- **Purpose**: Sends push notifications to chat participants when a new message is created
- **Region**: `europe-west1` (configurable in `src/index.ts`)

### `testPush` (Debug only)
- **Trigger**: HTTP POST
- **Purpose**: Test push notification delivery
- **⚠️ Remove in production or secure with authentication**

## Setup

### Prerequisites
1. Firebase CLI installed: `npm install -g firebase-tools`
2. Logged in: `firebase login`
3. Project selected: `firebase use <project-id>`

### Install Dependencies
```bash
cd functions
npm install
```

### Build
```bash
npm run build
```

### Deploy
```bash
npm run deploy
# or
firebase deploy --only functions
```

### Local Testing
```bash
npm run serve
# This starts the Firebase emulator
```

### View Logs
```bash
npm run logs
# or
firebase functions:log
```

## Configuration

### Region
Edit `REGION` constant in `src/index.ts`:
```typescript
const REGION = "europe-west1"; // Change to your preferred region
```

Available regions:
- `us-central1` (default)
- `europe-west1`
- `asia-northeast1`
- etc.

### Required Firebase Setup
1. Enable Cloud Messaging in Firebase Console
2. Upload APNs key for iOS
3. Ensure Firestore security rules allow device token writes

## Firestore Schema Expected

```
users/{uid}/devices/{deviceId}
  - fcmToken: string
  - platform: "ios" | "android"
  - locale: string (optional)
  - updatedAt: timestamp

chats/{threadId}
  - participantIds: string[]
  - ...

chats/{threadId}/messages/{msgId}
  - senderId: string
  - senderName: string
  - text: string
  - createdAt: timestamp
```

## Security Rules

Add to `firestore.rules`:
```javascript
// Device tokens - user can only manage their own devices
match /users/{uid}/devices/{deviceId} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```
