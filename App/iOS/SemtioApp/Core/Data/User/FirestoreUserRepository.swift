//
//  FirestoreUserRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  FINAL FIRESTORE USER SCHEMA:
//  users/{uid}/profile/info
//  - displayName: String
//  - username: String
//  - email: String?
//  ... [All Profile Fields]
//
//  users/{uid}/friendRequests/{requestUid}
//  - uid: String
//  - type: sent | received
//  - status: pending | accepted
//  - timestamp: date
//
//  users/{uid}/chats/{peerUid}
//  - [Chat Metadata]
//
//  - interests: [String] (default [])
//  - shareCode11: String (auto-generated if missing)
//  - isProfilePublic: Bool (default true)
//  - profileCompleted: Bool
//  - createdAt: serverTimestamp
//  - updatedAt: serverTimestamp
//

import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

final class FirestoreUserRepository: UserRepository {
    private let db = Firestore.firestore()
    
    // Wrapper for multiple listeners
    private class MultiListener {
        var listeners: [ListenerRegistration] = []
        func remove() { listeners.forEach { $0.remove() } }
    }
    
    // MARK: - Fetch User
    
    func fetchUser(id: String) async throws -> AppUser? {
        // Path: users/{id} (Flat)
        let docRef = db.collection("users").document(id)
        let snapshot = try await docRef.getDocument()
        
        guard snapshot.exists else { return nil }
        
        // Auto-provision missing fields (check against data, pass existing)
        // ONLY if we are the owner, otherwise we get permission error trying to write to another user's doc
        if let currentUid = Auth.auth().currentUser?.uid, currentUid == id {
             try await ensureRequiredFields(uid: id, docRef: docRef, existingData: snapshot.data() ?? [:])
             // Re-fetch only if we potentially changed something?
             // Actually, if we are owner, we can refetch.
             // If not owner, we just map existing data.
             let updatedSnapshot = try await docRef.getDocument()
             return try mapDocumentToUser(updatedSnapshot, uid: id)
        }
        
        // If not owner, just return what we found (read-only)
        return try mapDocumentToUser(snapshot, uid: id)
    }
    
    func fetchUser(username: String) async throws -> AppUser? {
        let snapshot = try await db.collection("users")
            .whereField("username", isEqualTo: username)
            .limit(to: 1)
            .getDocuments()
            
        guard let doc = snapshot.documents.first else { return nil }
        return try mapDocumentToUser(doc, uid: doc.documentID)
    }
    
    // MARK: - Save User
    
    func saveUser(_ user: AppUser) async throws {
        var data: [String: Any] = [
            "uid": user.id, // Explicit uid field as requested
            "fullName": user.fullName, // Field mapping per request
            "username": user.username ?? generateUsername(from: user.fullName),
            "usernameLowercase": (user.username ?? generateUsername(from: user.fullName)).lowercased(), // user request schema
            "bio": user.bio ?? "",
            "interests": user.interests ?? [],
            "isProfileComplete": user.isProfileComplete, // user request schema
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        // Optional fields mapping
        if let city = user.city { data["city"] = city }
        if let district = user.district { data["district"] = district } // Keep if needed, though not in strict schema list
        if let headline = user.headline { data["headline"] = headline }
        if let avatarURL = user.avatarURL { data["profilePicture"] = avatarURL } // mapped to 'profilePicture'
        
        // Exact Schema additions
        if let nickname = user.nickname { data["nickname"] = nickname }
        if let age = user.age { data["age"] = age }
        if let eyeColor = user.eyeColor { data["eyeColor"] = eyeColor }
        if let accountStatus = user.accountStatus { data["accountStatus"] = accountStatus }
        
        // Path: users/{id} (Flat)
        try await db.collection("users").document(user.id)
            .setData(data, merge: true)
            
        print("✅ FirestoreUserRepository: User \(user.id) saved to flat document")
    }
    
    // MARK: - Delete User
    
    func deleteUser(id: String) async throws {
        try await db.collection("users").document(id).delete()
        print("✅ FirestoreUserRepository: User \(id) deleted")
    }
    
    // MARK: - Search
    
    func searchUsers(query: String) async throws -> [UserLite] {
        guard !query.isEmpty else { return [] }
        print("🔍 USER_SEARCH query=\(query)")
        
        // SEARCH: Flat collection query
        let snapshot = try await db.collection("users")
            .whereField("username", isGreaterThanOrEqualTo: query)
            .whereField("username", isLessThan: query + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()
            
        return snapshot.documents.compactMap { doc -> UserLite? in
            let data = doc.data()
            let uid = doc.documentID
            
            return UserLite(
                id: uid,
                fullName: data["fullName"] as? String ?? "",
                username: data["username"] as? String ?? "",
                avatarURL: data["avatarURL"] as? String
            )
        }
    }
    
    // MARK: - Suggestions
    
    func fetchSuggestedUsers(limit: Int) async throws -> [AppUser] {
        // Suggestion from 'profile' collection group
        let snapshot = try await db.collectionGroup("profile")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
            
        return try snapshot.documents.compactMap { doc in
             let uid = doc.documentID
             return try mapDocumentToUser(doc, uid: uid)
        }
    }
    
    // MARK: - Listen User (Real-time)
    
    func listenUser(id: String, onChange: @escaping (AppUser?) -> Void, onError: @escaping (Error) -> Void) -> AnyObject? {
        // Listen to users/{id}
        let listener = db.collection("users").document(id)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    onError(error)
                    return
                }
                guard let snapshot = snapshot, snapshot.exists else {
                    onChange(nil)
                    return
                }
                
                do {
                    let user = try self.mapDocumentToUser(snapshot, uid: id)
                    onChange(user)
                } catch {
                    onError(error)
                }
            }
        return listener
    }
    
    func removeListener(_ listener: AnyObject) {
        if let registration = listener as? ListenerRegistration {
            registration.remove()
        } else if let multi = listener as? MultiListener {
            multi.remove()
        }
    }
    
    // MARK: - Upsert User (Auth callback)
    
    func upsertUser(id: String, email: String?, displayName: String?) async throws {
        // Upsert to users/{id}
        let docRef = db.collection("users").document(id)
        let snapshot = try await docRef.getDocument()
        
        var data: [String: Any] = [
            "id": id,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        if let email = email {
            data["email"] = email
        }
        
        if !snapshot.exists {
            // New user - set defaults
            data["createdAt"] = FieldValue.serverTimestamp()
            data["profileCompleted"] = false
            data["isProfilePublic"] = true
            data["interests"] = [String]()
            data["friends"] = 0
            data["friendIds"] = [String]()
            
            let name = displayName ?? "User"
            data["fullName"] = name // Used 'fullName' per request schema
            data["usernameLowercase"] = generateUsername(from: name).lowercased() // 'usernameLowercase'
            let uName = generateUsername(from: name)
            data["username"] = uName
            data["accountStatus"] = "active"
            
            print("✅ FirestoreUserRepository: New user \(id) created with defaults in flat doc")
        }
        
        try await docRef.setData(data, merge: true)
        
        // Ensure all fields for existing users
        if snapshot.exists {
            try await ensureRequiredFields(uid: id, docRef: docRef, existingData: snapshot.data() ?? [:])
        }
    }
    
    // MARK: - ShareCode
    
    func ensureShareCode(uid: String) async throws -> String {
        let docRef = db.collection("users").document(uid).collection("profile").document("info")
        let snapshot = try await docRef.getDocument()
        
        if let existingCode = snapshot.data()?["shareCode11"] as? String, !existingCode.isEmpty {
            return existingCode
        }
        
        let newCode = ShareCodeGenerator.generate()
        try await docRef.setData([
            "shareCode11": newCode,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        
        print("✅ FirestoreUserRepository: ShareCode generated for \(uid): \(newCode)")
        return newCode
    }
    
    func updateShareCode(uid: String, code: String) async throws {
        try await db.collection("users").document(uid).setData([
            "shareCode11": code,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
    
    // MARK: - Privacy
    
    func updateProfilePrivacy(uid: String, isPublic: Bool) async throws {
        try await db.collection("users").document(uid).collection("profile").document("info").setData([
            "isProfilePublic": isPublic,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        print("✅ FirestoreUserRepository: Privacy updated for \(uid): isPublic=\(isPublic)")
    }
    
    func fetchProfilePrivacy(uid: String) async throws -> Bool {
        let snapshot = try await db.collection("users").document(uid).collection("profile").document("info").getDocument()
        return snapshot.data()?["isProfilePublic"] as? Bool ?? true
    }
    
    // MARK: - Blocking
    
    func blockUser(uid: String, blockedUid: String) async throws {
        let ref = db.collection("users").document(uid)
            .collection("blocked").document(blockedUid)
        
        try await ref.setData([
            "blockedAt": FieldValue.serverTimestamp()
        ])
    }
    
    func unblockUser(uid: String, blockedUid: String) async throws {
        let ref = db.collection("users").document(uid)
            .collection("blocked").document(blockedUid)
        
        try await ref.delete()
    }
    
    func fetchBlockedUsers(uid: String) async throws -> Set<String> {
        let snapshot = try await db.collection("users").document(uid)
            .collection("blocked").getDocuments()
        
        return Set(snapshot.documents.map { $0.documentID })
    }
    
    // MARK: - Interests
    
    func updateInterests(uid: String, interests: [String]) async throws {
        try await db.collection("users").document(uid).collection("profile").document("info").setData([
            "interests": interests,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
        print("✅ FirestoreUserRepository: Interests updated for \(uid): \(interests.count) items")
    }
    
    // MARK: - Auto-Provision (CRITICAL)
    
    /// Ensures all required fields exist. Does NOT overwrite existing values.
    private func ensureRequiredFields(uid: String, docRef: DocumentReference, existingData: [String: Any]) async throws {
        var updates: [String: Any] = [:]
        
        // username: generate from displayName if missing
        if existingData["username"] == nil || (existingData["username"] as? String)?.isEmpty == true {
            let displayName = existingData["displayName"] as? String ?? "user"
            let generated = generateUsername(from: displayName)
            updates["username"] = generated
            updates["usernameLowercase"] = generated.lowercased()
        }
        
        // Ensure lowercase fields even if username exists
        if let username = existingData["username"] as? String, existingData["usernameLowercase"] == nil {
            updates["usernameLowercase"] = username.lowercased()
        }
        
        // shareCode11: generate if missing
            // shareCode11 removed from required check if not in strict schema, but good to keep if used elsewhere
             updates["shareCode11"] = ShareCodeGenerator.generate()
        
        // interests: default to empty array
        if existingData["interests"] == nil {
            updates["interests"] = [String]()
        }
        
        // isProfileComplete
        if existingData["isProfileComplete"] == nil {
            updates["isProfileComplete"] = false
        }
        
        // createdAt: set if missing
        if existingData["createdAt"] == nil {
            updates["createdAt"] = FieldValue.serverTimestamp()
        }
        
        // Write updates if any
        if !updates.isEmpty {
            updates["updatedAt"] = FieldValue.serverTimestamp()
            try await docRef.setData(updates, merge: true)
            print("✅ FirestoreUserRepository: Auto-provisioned \(updates.keys.count) fields for \(uid)")
        }
    }
    
    // MARK: - Helpers
    
    private func generateUsername(from displayName: String) -> String {
        let lowercased = displayName.lowercased()
        let alphanumeric = lowercased.filter { $0.isLetter || $0.isNumber }
        let base = alphanumeric.isEmpty ? "user" : String(alphanumeric.prefix(15))
        let suffix = String(Int.random(in: 100...999))
        return "\(base)\(suffix)"
    }
    
    private func mapDocumentToUser(_ doc: DocumentSnapshot, uid: String) throws -> AppUser {
        let data = doc.data() ?? [:]
        
        let displayName = data["fullName"] as? String ?? data["displayName"] as? String ?? "User"
        
        return AppUser(
            id: uid, 
            fullName: displayName,
            avatarAssetName: nil, 
            avatarURL: data["profilePicture"] as? String ?? data["avatarURL"] as? String, 
            headline: nil, 
            username: data["username"] as? String,
            city: data["city"] as? String,
            bio: data["bio"] as? String,
            interests: data["interests"] as? [String],
            profileCompleted: data["isProfileComplete"] as? Bool ?? data["profileCompleted"] as? Bool,
            profileImageData: nil,
            isProfilePublic: data["isProfilePublic"] as? Bool ?? true,
            shareCode11: data["shareCode11"] as? String,
            district: data["district"] as? String,
            isPremium: data["isPremium"] as? Bool,
            isDeleted: data["isDeleted"] as? Bool,
            
            // New Fields
            nickname: data["nickname"] as? String,
            age: data["age"] as? Int,
            eyeColor: data["eyeColor"] as? String,
            accountStatus: data["accountStatus"] as? String,
            
            friends: data["friends"] as? Int ?? 0,
            friendIds: data["friendIds"] as? [String] ?? [],
            eventsCreated: data["eventsCreated"] as? [String] ?? [],
            savedEventIds: data["savedEventIds"] as? [String] ?? []
        )
    }
    
    // MARK: - Saved Events (Subcollection)
    
    func saveEvent(eventId: String, uid: String) async throws {
        try await db.collection("users").document(uid)
            .collection("savedEvents").document(eventId)
            .setData([
                "savedAt": FieldValue.serverTimestamp()
            ])
        print("✅ FirestoreUserRepository: Saved event \(eventId) for user \(uid)")
    }
    
    func unsaveEvent(eventId: String, uid: String) async throws {
        try await db.collection("users").document(uid)
            .collection("savedEvents").document(eventId)
            .delete()
        print("✅ FirestoreUserRepository: Unsaved event \(eventId) for user \(uid)")
    }
    
    func fetchSavedEventIds(uid: String) async throws -> Set<String> {
        let snapshot = try await db.collection("users").document(uid)
            .collection("savedEvents")
            .getDocuments()
        
        let ids = Set(snapshot.documents.map { $0.documentID })
        print("✅ FirestoreUserRepository: Fetched \(ids.count) saved events for user \(uid)")
        return ids
    }
    
    // MARK: - Saved Posts
    
    func savePost(postId: String, uid: String) async throws {
        try await db.collection("users").document(uid)
            .collection("saved_posts").document(postId)
            .setData([
                "savedAt": FieldValue.serverTimestamp(),
                "postId": postId
            ], merge: true)
        print("✅ FirestoreUserRepository: Saved post \(postId) for user \(uid)")
    }
    
    func unsavePost(postId: String, uid: String) async throws {
        try await db.collection("users").document(uid)
            .collection("saved_posts").document(postId)
            .delete()
        print("✅ FirestoreUserRepository: Unsaved post \(postId) for user \(uid)")
    }
    
    func fetchSavedPostIds(uid: String) async throws -> Set<String> {
        let snapshot = try await db.collection("users").document(uid)
            .collection("saved_posts")
            .getDocuments()
        
        let ids = Set(snapshot.documents.map { $0.documentID })
        return ids
    }
    
    // MARK: - Friends / Requests (Real Implementation)
    
    // MARK: - Friends / Requests (NEW SUBCOLLECTION)
    
    func sendFriendRequest(fromUid: String, toUid: String) async throws {
        guard fromUid != toUid else { return }
        
        let batch = db.batch()
        let now = FieldValue.serverTimestamp()
        
        // 1. Users/toUid/friendRequests/fromUid (Received)
        let inboundRef = db.collection("users").document(toUid)
            .collection("friendRequests").document(fromUid)
        
        let inboundData: [String: Any] = [
            "uid": fromUid, // The sender
            "type": "received",
            "status": "pending",
            "timestamp": now
        ]
        batch.setData(inboundData, forDocument: inboundRef)
        
        // 2. Users/fromUid/friendRequests/toUid (Sent)
        let outboundRef = db.collection("users").document(fromUid)
            .collection("friendRequests").document(toUid)
        
        let outboundData: [String: Any] = [
            "uid": toUid, // The receiver
            "type": "sent",
            "status": "pending",
            "timestamp": now
        ]
        batch.setData(outboundData, forDocument: outboundRef)
        
        try await batch.commit()
    }
    
    func acceptFriendRequest(requestId: String, fromUid: String, toUid: String) async throws {
        let batch = db.batch()
        let now = FieldValue.serverTimestamp()
        
        // 1. Remove from requests (both sides)
        let myReq = db.collection("users").document(toUid)
            .collection("friendRequests").document(fromUid)
        batch.deleteDocument(myReq)
        
        let theirReq = db.collection("users").document(fromUid)
            .collection("friendRequests").document(toUid)
        batch.deleteDocument(theirReq)
        
        // 2. Add to Friends List (User Subcollection)
        // Path: users/{uid}/friends/{friendUid}
        let friendRef1 = db.collection("users").document(fromUid).collection("friends").document(toUid)
        let friendRef2 = db.collection("users").document(toUid).collection("friends").document(fromUid)
        
        batch.setData(["since": now, "uid": toUid], forDocument: friendRef1)
        batch.setData(["since": now, "uid": fromUid], forDocument: friendRef2)
        
        // 3. Update Denormalized Friend IDs and Counts in User Doc
        let userRef1 = db.collection("users").document(fromUid)
        let userRef2 = db.collection("users").document(toUid)
        
        batch.updateData([
            "friendIds": FieldValue.arrayUnion([toUid]),
            "friends": FieldValue.increment(Int64(1))
        ], forDocument: userRef1)
        
        batch.updateData([
            "friendIds": FieldValue.arrayUnion([fromUid]),
            "friends": FieldValue.increment(Int64(1))
        ], forDocument: userRef2)
        
        try await batch.commit()
    }
    
    func rejectFriendRequest(requestId: String) async throws {
        // We need sender/receiver context to delete from both. 
        // If we only have "requestId" which maps to fromUid/sender, we need to know who is rejecting (current user).
        // Let's assume current user is the receiver "toUid".
        guard let currentUser = Auth.auth().currentUser else { return } 
        let currentUid = currentUser.uid
        let senderUid = requestId // In inbox, ID is senderUid
        
        try await cancelFriendRequestLogic(senderUid: senderUid, receiverUid: currentUid)
    }
    
    func cancelFriendRequest(requestId: String) async throws {
        // Cancelling outgoing request.
        guard let currentUser = Auth.auth().currentUser else { return }
        let currentUid = currentUser.uid
        let receiverUid = requestId // In outbox, ID is receiverUid
        
        try await cancelFriendRequestLogic(senderUid: currentUid, receiverUid: receiverUid)
    }
    
    private func cancelFriendRequestLogic(senderUid: String, receiverUid: String) async throws {
        let batch = db.batch()
        
        // 1. Remove from receiver's requests
        let receiverRef = db.collection("users").document(receiverUid)
            .collection("friendRequests").document(senderUid)
        batch.deleteDocument(receiverRef)
        
        // 2. Remove from sender's requests
        let senderRef = db.collection("users").document(senderUid)
            .collection("friendRequests").document(receiverUid)
        batch.deleteDocument(senderRef)
        
        try await batch.commit()
    }

    func unfriend(uid: String, friendUid: String) async throws {
        let batch = db.batch()
        // Path: users/{uid}/friends/{friendUid}
        let ref1 = db.collection("users").document(uid).collection("friends").document(friendUid)
        let ref2 = db.collection("users").document(friendUid).collection("friends").document(uid)
        
        batch.deleteDocument(ref1)
        batch.deleteDocument(ref2)
        
        // Remove from Denormalized fields
        let userRef1 = db.collection("users").document(uid)
        let userRef2 = db.collection("users").document(friendUid)
        
        batch.updateData([
            "friendIds": FieldValue.arrayRemove([friendUid]),
            "friends": FieldValue.increment(Int64(-1))
        ], forDocument: userRef1)
        
        batch.updateData([
            "friendIds": FieldValue.arrayRemove([uid]),
            "friends": FieldValue.increment(Int64(-1))
        ], forDocument: userRef2)
        
        try await batch.commit()
    }

    func listenFriendRequests(uid: String, onChange: @escaping ([FriendRequest]) -> Void, onError: @escaping (Error) -> Void) -> AnyObject? {
        // Listening to /users/{uid}/friendRequests
        // Filter for type='received' to show incoming requests
        
        let wrapper = MultiListener()
        
        let listener = db.collection("users").document(uid).collection("friendRequests")
            .whereField("type", isEqualTo: "received")
            .whereField("status", isEqualTo: "pending")
            // Removed .order(by: "timestamp") to avoid needing a composite index.
            // Sorting is done client-side below.
            .addSnapshotListener { snapshot, error in
                if let error = error { onError(error); return }
                var requests = snapshot?.documents.compactMap { self.mapRequest($0) } ?? []
                
                // Client-side sort
                requests.sort { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
                
                onChange(requests)
            }
            
        wrapper.listeners = [listener]
        return wrapper
    } 
    
    private func mapRequest(_ doc: DocumentSnapshot) -> FriendRequest? {
        guard let data = doc.data() else { return nil }
        
        let uid = data["uid"] as? String ?? ""
        
        return FriendRequest(
            id: uid, 
            fromUid: (data["type"] as? String == "received") ? uid : "", 
            toUid: (data["type"] as? String == "sent") ? uid : "",
            status: data["status"] as? String ?? "pending",
            createdAt: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
        )
    }

    func fetchFriends(uid: String) async throws -> [AppUser] {
        // Path: users/{uid}/friends
        let snapshot = try await db.collection("users").document(uid).collection("friends").getDocuments()
        let friendIds = snapshot.documents.map { $0.documentID }
        
        print("🔍 FirestoreUserRepository: fetchFriends found \(friendIds.count) IDs in subcollection: \(friendIds)")
        
        guard !friendIds.isEmpty else { return [] }
        
        // Fetch user profiles in chunks
        var friends: [AppUser] = []
        let chunks = friendIds.chunked(into: 10)
        for chunk in chunks {
            try await withThrowingTaskGroup(of: AppUser?.self) { group in
                for friendUid in chunk {
                    group.addTask {
                        // Try Flat Schema First
                        // Try Flat Schema First
                        let ref = self.db.collection("users").document(friendUid)
                        var doc = try await ref.getDocument()
                        
                        // Fallback to Legacy Schema
                        if !doc.exists {
                             doc = try await ref.collection("profile").document("info").getDocument()
                        }
                        
                        if !doc.exists { 
                            print("⚠️ FirestoreUserRepository: Friend doc missing for \(friendUid)")
                            return nil 
                        }
                        
                        // print("✅ FirestoreUserRepository: Found friend \(friendUid) via \(source)")
                        return try self.mapDocumentToUser(doc, uid: friendUid)
                    }
                }
                
                for try await user in group {
                    if let user = user {
                        friends.append(user)
                    }
                }
            }
        }
        print("✅ FirestoreUserRepository: Returning \(friends.count) friend objects")
        return friends
    }
    

}

