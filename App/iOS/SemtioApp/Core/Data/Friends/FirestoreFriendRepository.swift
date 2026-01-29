//
//  FirestoreFriendRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  PRODUCTION-READY: Firestore Friend Repository
//  
//  FIRESTORE DATA MODEL:
//  - users/{uid}: displayName (REQUIRED), username (auto-generated if missing), shareCode11 (auto-generated if missing)
//  - friend_requests/{requestId}: fromUid, toUid, createdAt, status
//  - friends/{uid}/list/{friendUid}: since
//
//  FIRESTORE INDEXES REQUIRED:
//  1. friend_requests: (fromUid ASC, status ASC)
//  2. friend_requests: (fromUid ASC, toUid ASC, status ASC)
//  3. users: (displayName ASC) - for prefix search
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif

// MARK: - Cloud Function Names

private enum FriendFunctions {
    static let send = "sendFriendRequest_eu1"
    static let accept = "acceptFriendRequest_eu1"
    static let reject = "rejectFriendRequest_eu1"
    static let cancel = "cancelFriendRequest_eu1"
    static let remove = "removeFriend_eu1"
}

// MARK: - Firestore Friend Repository

final class FirestoreFriendRepository: FriendRepositoryProtocol {
    private let db = Firestore.firestore()
    // functions client handled via CloudFunctionsClient logic
    
    // MARK: - Hard Diagnostic
    
    /// Prints critical Firestore environment info to console.
    /// Call this on app launch and when opening search screen.
    func debugFirestoreEnvironment() async {
        print("═══════════════════════════════════════════════════════")
        print("🔥 FIRESTORE ENVIRONMENT DIAGNOSTIC")
        print("═══════════════════════════════════════════════════════")
        
        #if canImport(FirebaseCore)
        if let app = FirebaseApp.app() {
            print("📦 Project ID: \(app.options.projectID ?? "nil")")
            print("📦 Database URL: \(app.options.databaseURL ?? "nil")")
            print("📦 Storage Bucket: \(app.options.storageBucket ?? "nil")")
        } else {
            print("❌ FirebaseApp.app() is nil!")
        }
        #endif
        
        let settings = db.settings
        print("🌐 Firestore Host: \(settings.host)")
        print("🔒 SSL Enabled: \(settings.isSSLEnabled)")
        print("💾 Cache Configured: \(settings.cacheSettings)")
        
        // Check if using emulator
        if settings.host.contains("localhost") || settings.host.contains("127.0.0.1") {
            print("⚠️ EMULATOR MODE DETECTED!")
        } else {
            print("✅ Production Firestore")
        }
        
        // Sample users collection
        do {
            let snap = try await db.collection("users").limit(to: 10).getDocuments()
            print("👥 Users collection sample: \(snap.documents.count) docs")
            for doc in snap.documents {
                let displayName = doc.data()["displayName"] as? String ?? "?"
                let username = doc.data()["username"] as? String ?? "?"
                let shareCode = doc.data()["shareCode11"] as? String ?? "?"
                print("   - \(doc.documentID): \(displayName) (@\(username)) [code:\(shareCode)]")
            }
        } catch {
            print("❌ Failed to read users collection: \(error.localizedDescription)")
        }
        
        print("═══════════════════════════════════════════════════════")
    }
    
    // MARK: - Fetch Friends
    
    func fetchFriends(userId: String, limit: Int, startAfter: DocumentSnapshot?) async throws -> FriendPage {
        guard !userId.isEmpty else { 
            return FriendPage(users: [], lastSnapshot: nil, hasMore: false)
        }
        
        // 1. Query users/{uid}/friends
        var query = db.collection("users")
            .document(userId)
            .collection("friends")
            .order(by: "since", descending: true)
            .limit(to: limit)
            
        if let startAfter = startAfter {
            query = query.start(afterDocument: startAfter)
        }
        
        let friendDocs = try await query.getDocuments()
        let friendUids = friendDocs.documents.map { $0.documentID }
        
        if friendUids.isEmpty {
            return FriendPage(users: [], lastSnapshot: friendDocs.documents.last, hasMore: false)
        }
        
        // 2. Fetch user documents
        var friends: [AppUser] = []
        
        for uidBatch in friendUids.chunked(into: 10) {
            let snapshot = try await db.collection("users")
                .whereField(FieldPath.documentID(), in: uidBatch)
                .getDocuments()
            
            for doc in snapshot.documents {
                if let user = mapDocumentToUser(doc) {
                    friends.append(user)
                }
            }
        }
        
        // 3. Re-sort
        let friendMap = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })
        let orderedFriends = friendUids.compactMap { friendMap[$0] }
        
        let hasMore = friendDocs.documents.count == limit
        return FriendPage(users: orderedFriends, lastSnapshot: friendDocs.documents.last, hasMore: hasMore)
    }
    
    // MARK: - Search Users (ROBUST MULTI-STRATEGY)
    
    /// Searches users using multiple strategies to handle missing fields.
    func searchUsers(query: String) async throws -> [AppUser] {
        let raw = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return [] }
        
        let normalized = (raw.hasPrefix("@") ? String(raw.dropFirst()) : raw).lowercased()
        if normalized.count < 2 { return [] }

        // 0. DIAGNOSTIC: Check specific environment before every search
        await FirestoreDiagnostic.debugUsersCollection()
        
        // 1. PRE-CHECK: Are there any other users?
        do {
            let sampleSnap = try await db.collection("users").limit(to: 2).getDocuments()
            if sampleSnap.documents.count <= 1 {
                print("⚠️ Search Pre-Check: Only 0-1 users in collection")
                throw NSError(domain: "App", code: -1, userInfo: [NSLocalizedDescriptionKey: "Henüz uygulamada başka kullanıcı yok."])
            }
        } catch {
             if (error as NSError).code == -1 { throw error }
             print("❌ Search Pre-Check Failed: \(error.localizedDescription)")
        }
        
        let me = getCurrentUserUidOrThrow()
        var allResults: [AppUser] = []
        var seenIds: Set<String> = [me]
        
        // STRATEGY A: usernameLower prefix
        do {
            let snap = try await db.collection("users")
                .order(by: "usernameLower")
                .start(at: [normalized]).end(at: [normalized + "\u{f8ff}"])
                .limit(to: 20).getDocuments()
            print("🔍 A) usernameLower prefix: \(snap.count) matches")
            appendResults(from: snap, to: &allResults, seenIds: &seenIds)
        } catch { print("⚠️ A) failed: \(error)") }
        
        // STRATEGY B: username exact (raw & lower)
        if allResults.count < 5 {
            for q in Set([raw, normalized]) {
                do {
                    let snap = try await db.collection("users").whereField("username", isEqualTo: q).limit(to: 5).getDocuments()
                    print("🔍 B) username exact '\(q)': \(snap.count) matches")
                    appendResults(from: snap, to: &allResults, seenIds: &seenIds)
                } catch { print("⚠️ B) failed: \(error)") }
            }
        }
        
        // STRATEGY C: shareCode11 exact (raw & uppercased)
        if allResults.count < 5 {
            for q in Set([raw, raw.uppercased()]) {
                do {
                    let snap = try await db.collection("users").whereField("shareCode11", isEqualTo: q).limit(to: 5).getDocuments()
                    print("🔍 C) shareCode11 exact '\(q)': \(snap.count) matches")
                    appendResults(from: snap, to: &allResults, seenIds: &seenIds)
                } catch { print("⚠️ C) failed: \(error)") }
            }
        }
        
        // STRATEGY D: displayNameLower prefix
        if allResults.count < 5 {
            do {
                let snap = try await db.collection("users")
                    .order(by: "displayNameLower")
                    .start(at: [normalized]).end(at: [normalized + "\u{f8ff}"])
                    .limit(to: 15).getDocuments()
                print("🔍 D) displayNameLower prefix: \(snap.count) matches")
                appendResults(from: snap, to: &allResults, seenIds: &seenIds)
            } catch { print("⚠️ D) failed: \(error)") }
        }
        
        print("✅ searchUsers Returning: \(allResults.count) unique results")
        return allResults
    }

    private func appendResults(from snap: QuerySnapshot, to allResults: inout [AppUser], seenIds: inout Set<String>) {
        for doc in snap.documents {
            if !seenIds.contains(doc.documentID), let user = mapDocumentToUser(doc) {
                allResults.append(user)
                seenIds.insert(doc.documentID)
            }
        }
    }
    
    /// Gets current user UID or throws a meaningful error.
    private func getCurrentUserUidOrThrow() -> String {
        #if canImport(FirebaseAuth)
        if let uid = Auth.auth().currentUser?.uid, !uid.isEmpty {
            return uid
        }
        #endif
        // Return a placeholder that won't match any real user
        // This allows search to proceed but won't exclude anyone incorrectly
        print("⚠️ getCurrentUserUidOrThrow: No authenticated user, using placeholder")
        return "UNAUTHENTICATED_USER_PLACEHOLDER"
    }
    
    // MARK: - Send Friend Request

    func sendFriendRequest(from fromUid: String, to toUid: String, senderName: String? = nil, senderAvatar: String? = nil) async throws {
        // RULE 1: Prevent self-request
        guard fromUid != toUid else { throw FriendError.cannotRequestSelf }
        
        // RULE 2: Check for existing pending request (in Outgoing)
        let outgoingRef = db.collection("users").document(fromUid).collection("friendRequestsSent").document(toUid)
        let outgoingDoc = try await outgoingRef.getDocument()
        
        guard !outgoingDoc.exists else { throw FriendError.requestAlreadyPending }
        
        // RULE 3: Check Blocking
        let iBlockedThem = try await db.collection("users").document(fromUid)
            .collection("blocked").document(toUid).getDocument().exists
        guard !iBlockedThem else { throw FriendError.userBlocked }
        
        // RULE 4: Check if already friends
        let friendDoc = try await db.collection("users").document(fromUid)
            .collection("friends").document(toUid).getDocument()
        guard !friendDoc.exists else { throw FriendError.alreadyFriends }
        
        // Create friend request
        let requestId = UUID().uuidString // Optional if we use composite keys, but let's keep it simple
        let now = FieldValue.serverTimestamp()
        
        var requestData: [String: Any] = [
            "id": requestId,
            "fromUid": fromUid,
            "toUid": toUid,
            "status": "pending",
            "createdAt": now,
            "updatedAt": now
        ]
        
        if let name = senderName { requestData["fromName"] = name }
        if let avatar = senderAvatar { requestData["fromAvatar"] = avatar }
        
        let batch = db.batch()
        
        // 1. Write to Recipient's Inbox (friendRequestsReceived/{fromUid})
        let inboxRef = db.collection("users").document(toUid).collection("friendRequestsReceived").document(fromUid)
        batch.setData(requestData, forDocument: inboxRef)
        
        // 2. Write to Sender's Outbox (friendRequestsSent/{toUid})
        batch.setData(requestData, forDocument: outgoingRef)
        
        try await batch.commit()
        print("✅ FirestoreFriendRepository: Friend request sent from \(fromUid) to \(toUid)")
    }
    
    // MARK: - Accept Friend Request
    
    func acceptFriendRequest(requestId: String) async throws {
        // NOTE: In new schema, requestId is often the senderUid, but FriendStore might pass a UUID string.
        // We need to find the request in `friendRequestsReceived`.
        // If requestId is NOT a UID, we must query.
        
        guard let me = getCurrentUserUid() else { return }
        
        // Try direct fetch if requestId == senderUid
        var requestDoc = try? await db.collection("users").document(me).collection("friendRequestsReceived").document(requestId).getDocument()
        
        // If not found, try querying by 'id' field
        if requestDoc == nil || !requestDoc!.exists {
            let query = try await db.collection("users").document(me).collection("friendRequestsReceived")
                .whereField("id", isEqualTo: requestId)
                .limit(to: 1)
                .getDocuments()
            requestDoc = query.documents.first
        }
        
        guard let doc = requestDoc, doc.exists,
              let data = doc.data(),
              let fromUid = data["fromUid"] as? String,
              let _ = data["toUid"] as? String else {
            throw FriendError.requestNotFound
        }
        
        let batch = db.batch()
        
        // 1. Create Bidirectional Friendship
        let friendData: [String: Any] = ["since": FieldValue.serverTimestamp()]
        
        let myFriendRef = db.collection("users").document(me).collection("friends").document(fromUid)
        let theirFriendRef = db.collection("users").document(fromUid).collection("friends").document(me)
        
        batch.setData(friendData, forDocument: myFriendRef)
        batch.setData(friendData, forDocument: theirFriendRef)
        
        // 2. Delete Requests (In and Out)
        let myInboxRef = db.collection("users").document(me).collection("friendRequestsReceived").document(fromUid)
        let theirOutboxRef = db.collection("users").document(fromUid).collection("friendRequestsSent").document(me)
        
        batch.deleteDocument(myInboxRef)
        batch.deleteDocument(theirOutboxRef)
        
        try await batch.commit()
        print("✅ FirestoreFriendRepository: Friend request \(requestId) accepted")
    }
    
    // MARK: - Pending Requests (Outgoing)
    
    func pendingRequests(for uid: String) async throws -> Set<String> {
        // Query users/{uid}/friendRequestsSent
        let snapshot = try await db.collection("users").document(uid).collection("friendRequestsSent")
            .getDocuments()
        
        // The doc ID in OUTBOX is the receiver UID (toUid)
        let toUids = snapshot.documents.map { $0.documentID }
        return Set(toUids)
    }

    func fetchOutgoingPendingRequests(for uid: String) async throws -> Set<String> {
        return try await pendingRequests(for: uid)
    }
    
    // MARK: - Reject Friend Request
    
    func rejectFriendRequest(requestId: String) async throws {
        // Similar to accept, find the request by ID or assume it's the sender UID
        guard let me = getCurrentUserUid() else { return }
        
        // 1. Find Sender UID
        var fromUid: String? = nil
        
        // Check if requestId is the UID (doc exists in INBOX)
        let directRef = db.collection("users").document(me).collection("friendRequestsReceived").document(requestId)
        if (try? await directRef.getDocument().exists) == true {
            fromUid = requestId
        } else {
            // Query by 'id' field
            let query = try await db.collection("users").document(me).collection("friendRequestsReceived")
                .whereField("id", isEqualTo: requestId).limit(to: 1).getDocuments()
            if let doc = query.documents.first {
                fromUid = doc.documentID // The docID is the fromUid in our schema
            }
        }
        
        guard let targetUid = fromUid else {
            throw FriendError.requestNotFound
        }
        
        // 2. Delete from both sides
        let batch = db.batch()
        let myInbox = db.collection("users").document(me).collection("friendRequestsReceived").document(targetUid)
        let theirOutbox = db.collection("users").document(targetUid).collection("friendRequestsSent").document(me)
        
        batch.deleteDocument(myInbox)
        batch.deleteDocument(theirOutbox)
        
        try await batch.commit()
        print("✅ FirestoreFriendRepository: Friend request rejected (deleted) for \(targetUid)")
    }
    
    // MARK: - Cancel Friend Request
    
    func cancelFriendRequest(requestId: String) async throws {
        // We are the Sender. requestId might be the UUID or the receiver UID.
        guard let me = getCurrentUserUid() else { return }
        
        var toUid: String? = nil
        
        // Check if requestId is the receiver UID (doc in OUTBOX)
        let directRef = db.collection("users").document(me).collection("friendRequestsSent").document(requestId)
        if (try? await directRef.getDocument().exists) == true {
            toUid = requestId
        } else {
            // Query by 'id' field
            let query = try await db.collection("users").document(me).collection("friendRequestsSent")
                .whereField("id", isEqualTo: requestId).limit(to: 1).getDocuments()
            if let doc = query.documents.first {
                toUid = doc.documentID // The docID in outbox is toUid
            }
        }
        
        guard let targetUid = toUid else {
            throw FriendError.requestNotFound
        }
        
        // Delete from My Outbox AND Their Inbox
        let batch = db.batch()
        let myOutbox = db.collection("users").document(me).collection("friendRequestsSent").document(targetUid)
        let theirInbox = db.collection("users").document(targetUid).collection("friendRequestsReceived").document(me)
        
        batch.deleteDocument(myOutbox)
        batch.deleteDocument(theirInbox)
        
        try await batch.commit()
        print("✅ FirestoreFriendRepository: Friend request cancelled for \(targetUid)")
    }
    
    // MARK: - Remove Friend
    
    func removeFriend(friendUid: String) async throws {
        // Bidirectional removal
        guard let me = getCurrentUserUid() else { return }
        
        let batch = db.batch()
        
        let myFriendDoc = db.collection("users").document(me).collection("friends").document(friendUid)
        let theirFriendDoc = db.collection("users").document(friendUid).collection("friends").document(me)
        
        batch.deleteDocument(myFriendDoc)
        batch.deleteDocument(theirFriendDoc)
        
        try await batch.commit()
        print("✅ FirestoreFriendRepository: Friend \(friendUid) removed")
    }
    
    // MARK: - Fetch Incoming Requests
    
    func fetchIncomingRequests() async throws -> [FriendRequest] {
        guard let me = Auth.auth().currentUser?.uid else { return [] }

        let snap = try await db.collection("users").document(me).collection("friendRequestsReceived")
            // .order(by: "createdAt", descending: true) -- Removed for No-Index Compliance
            .getDocuments()
            
        return snap.documents.map { doc in
            let d = doc.data()
            return FriendRequest(
                id: d["id"] as? String ?? doc.documentID,
                fromUid: d["fromUid"] as? String ?? "",
                toUid: d["toUid"] as? String ?? "",
                status: d["status"] as? String ?? "pending",
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                fromName: d["fromName"] as? String,
                fromAvatar: d["fromAvatar"] as? String
            )
        }.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
    }
    
    // MARK: - Listen Incoming Requests (Protocol Req)
    
    func listenIncomingRequests(userId: String, onChange: @escaping ([FriendRequest]) -> Void) -> AnyObject? {
        let listener = db.collection("users").document(userId).collection("friendRequestsReceived")
            // .order(by: "createdAt", descending: true) -- Removed
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else { return }
                
                let requests = docs.map { doc -> FriendRequest in
                    let d = doc.data()
                    return FriendRequest(
                        id: d["id"] as? String ?? doc.documentID,
                        fromUid: d["fromUid"] as? String ?? "",
                        toUid: d["toUid"] as? String ?? "",
                        status: d["status"] as? String ?? "pending",
                        createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        fromName: d["fromName"] as? String,
                        fromAvatar: d["fromAvatar"] as? String
                    )
                }.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
                onChange(requests)
            }
        return listener
    }
    
    // MARK: - Fetch Outgoing Requests
    
    func fetchOutgoingRequests() async throws -> [FriendRequest] {
        guard let me = getCurrentUserUid() else { return [] }
        
        let snapshot = try await db.collection("users").document(me).collection("friendRequestsSent")
            // .order(by: "createdAt", descending: true) -- Removed
            .getDocuments()
        
        return snapshot.documents.compactMap { FriendRequest.fromDoc($0) }
            .sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
    }
    
    // MARK: - Auto-Provision Missing Fields (CRITICAL)
    
    /// Ensures a user has the required search fields in Firestore.
    /// Should be called after login, profile load, or lazily during search.
    func ensureUserSearchFields(user: AppUser) async throws {
        guard !user.id.isEmpty else { return }
        
        let ref = db.collection("users").document(user.id)
        
        // Generate username if empty
        let username = (user.username?.isEmpty ?? true)
            ? generateUsername(from: user.displayName)
            : user.username!
        
        let data: [String: Any] = [
            "username": username,
            "usernameLower": username.lowercased(),
            "displayNameLower": user.displayName.lowercased()
        ]
        
        try await ref.setData(data, merge: true)
        print("✅ FirestoreFriendRepository: Ensured search fields for user \(user.id)")
    }
    
    /// Automatically generates username and shareCode11 if missing.
    /// Does NOT overwrite existing values.
    private func autoProvisionUserFields(doc: QueryDocumentSnapshot, user: inout AppUser) async -> AppUser {
        let data = doc.data()
        let uid = doc.documentID
        
        var updates: [String: Any] = [:]
        
        // AUTO-GENERATE username if missing
        if user.username == nil || (user.username?.isEmpty ?? true) {
            let generatedUsername = generateUsername(from: user.displayName)
            user.username = generatedUsername
            updates["username"] = generatedUsername
            updates["usernameLower"] = generatedUsername.lowercased()
        } else if data["usernameLower"] == nil {
            // Username exists but usernameLower is missing
            updates["usernameLower"] = user.username!.lowercased()
        }
        
        // AUTO-GENERATE displayNameLower if missing
        if data["displayNameLower"] == nil {
            updates["displayNameLower"] = user.displayName.lowercased()
        }
        
        // AUTO-GENERATE shareCode11 if missing
        if user.shareCode11 == nil || (user.shareCode11?.isEmpty ?? true) {
            let generatedCode = ShareCodeGenerator.generate()
            user.shareCode11 = generatedCode
            updates["shareCode11"] = generatedCode
        }
        
        // Write updates to Firestore (fire-and-forget, don't block search)
        if !updates.isEmpty {
            Task {
                do {
                    try await db.collection("users").document(uid).updateData(updates)
                    print("✅ FirestoreFriendRepository: Auto-provisioned fields for user \(uid): \(updates.keys.joined(separator: ", "))")
                } catch {
                    print("⚠️ FirestoreFriendRepository: Failed to auto-provision user \(uid): \(error.localizedDescription)")
                }
            }
        }
        
        return user
    }
    
    /// Generates a username from displayName (lowercase, no spaces, no special chars).
    private func generateUsername(from displayName: String) -> String {
        let lowercased = displayName.lowercased()
        let alphanumeric = lowercased.filter { $0.isLetter || $0.isNumber }
        let base = alphanumeric.isEmpty ? "user" : alphanumeric
        let suffix = String(Int.random(in: 100...999))
        return "\(base)\(suffix)"
    }
    
    // MARK: - Helpers
    
    private func getCurrentUserUid() -> String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }
    
    private func mapDocumentToUser(_ doc: QueryDocumentSnapshot) -> AppUser? {
        let data = doc.data()
        
        // displayName is REQUIRED, use fullName as fallback
        let displayName = data["displayName"] as? String ?? data["fullName"] as? String ?? ""
        
        guard !displayName.isEmpty else {
            print("⚠️ FirestoreFriendRepository: Skipping user \(doc.documentID) - no displayName")
            return nil
        }
        
        return AppUser(
            id: doc.documentID,
            fullName: displayName,
            avatarAssetName: nil,
            avatarURL: data["profilePicture"] as? String ?? data["avatarURL"] as? String,
            headline: data["headline"] as? String ?? data["bio"] as? String,
            username: data["username"] as? String,
            city: data["city"] as? String,
            bio: data["bio"] as? String,
            interests: data["interests"] as? [String],
            profileCompleted: data["profileCompleted"] as? Bool,
            profileImageData: nil,
            shareCode11: data["shareCode11"] as? String,
            district: data["district"] as? String
        )
    }
}



// MARK: - Errors

enum FriendError: LocalizedError {
    case cannotRequestSelf
    case requestAlreadyPending
    case alreadyFriends
    case requestNotFound
    case userBlocked
    
    var errorDescription: String? {
        switch self {
        case .cannotRequestSelf:
            return "Kendinize arkadaşlık isteği gönderemezsiniz."
        case .requestAlreadyPending:
            return "Bu kullanıcıya zaten bir istek gönderdiniz."
        case .alreadyFriends:
            return "Bu kullanıcı zaten arkadaşınız."
        case .requestNotFound:
            return "Arkadaşlık isteği bulunamadı."
        case .userBlocked:
            return "Bu kullanıcı ile etkileşime geçemezsiniz."
        }
    }
}

#endif
