# Setup Guide

## Prerequisites

- **macOS** with Xcode 16+
- **Node.js** 22+ (for Firebase Functions)
- **Firebase CLI** (`npm install -g firebase-tools`)
- **Apple Developer Account** (for device testing)

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/alazerekull/semtio.git
cd semtio
```

### 2. iOS App Setup

```bash
# Open in Xcode
open App/iOS/SemtioApp.xcworkspace
```

In Xcode:
1. Wait for SPM packages to resolve (Firebase, GoogleSignIn)
2. Select your team in Signing & Capabilities
3. Build and run on simulator

### 3. Firebase Setup

```bash
# Login to Firebase
firebase login

# Install function dependencies
cd Backend/Firebase/functions
npm install

# Build functions
npm run build

# Deploy (optional)
firebase deploy
```

## Configuration Files

### iOS (`GoogleService-Info.plist`)

Located at: `/App/iOS/GoogleService-Info.plist`

Contains:
- Firebase project ID
- API keys
- Bundle ID configuration

> ⚠️ This file is required for Firebase to work. Get it from Firebase Console.

### Firebase (`.firebaserc`)

```json
{
  "projects": {
    "default": "semtio"
  }
}
```

## Development Workflow

### Running iOS App

1. Open `App/iOS/SemtioApp.xcworkspace`
2. Select target device/simulator
3. Press ⌘R to build and run

### Running Firebase Emulator

```bash
# Start all emulators
firebase emulators:start

# Start specific emulators
firebase emulators:start --only functions,firestore
```

### Deploying Changes

```bash
# Deploy everything
firebase deploy

# Deploy functions only
firebase deploy --only functions

# Deploy rules only
firebase deploy --only firestore:rules
```

## Troubleshooting

### SPM Package Resolution Failed

```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/SemtioApp-*

# In Xcode: File > Packages > Reset Package Caches
```

### Firebase Functions Build Error

```bash
cd Backend/Firebase/functions
rm -rf node_modules
npm install
npm run build
```

### Signing Issues

1. Open Xcode project settings
2. Go to Signing & Capabilities
3. Select your team
4. Enable "Automatically manage signing"

## Project Structure Reference

```
SemtioProject/
├── App/iOS/                    # iOS Application
├── Backend/Firebase/           # Firebase Backend
├── docs/                       # Documentation
├── firebase.json              # Firebase config
└── .gitignore
```
