# Semtio - iOS Social Networking App

Welcome to the Semtio project wiki! This documentation covers the project structure, architecture, and setup instructions.

## Quick Links

- [Project Structure](Project-Structure)
- [iOS App Architecture](iOS-App-Architecture)
- [Firebase Backend](Firebase-Backend)
- [Setup Guide](Setup-Guide)

---

## Overview

**Semtio** is a SwiftUI-based iOS social networking application with Firebase backend.

| Component | Technology |
|-----------|------------|
| iOS App | SwiftUI, iOS 17+ |
| Backend | Firebase (Firestore, Auth, Functions, Storage) |
| Authentication | Apple Sign-In, Google Sign-In |
| Cloud Functions | TypeScript, Node.js 22 |

## Repository Structure

```
SemtioProject/
├── App/iOS/                    # iOS Application
│   ├── SemtioApp.xcodeproj
│   ├── SemtioApp.xcworkspace
│   ├── SemtioApp/              # Source code (278 Swift files)
│   └── GoogleService-Info.plist
├── Backend/Firebase/           # Firebase Backend
│   ├── functions/              # Cloud Functions
│   ├── firestore.rules
│   ├── firestore.indexes.json
│   └── storage.rules
├── firebase.json
└── .firebaserc
```
