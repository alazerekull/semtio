import FirebaseFirestore
import FirebaseAuth
import Combine

final class FirestoreChatRepository: ChatRepositoryProtocol {
    private let db = Firestore.firestore()
    
    // NEW: Helper to get current UID safely or pass it
    private var currentUid: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - List
    
    func fetchThreads(forUserId uid: String) async throws -> [ChatThread] {
        // Fetch Private Chats from users/{uid}/chats
        // Note: For groups, we might still need the 'dms' collection if they are not stored here.
        // Assuming pure migration to new schema for DMs.
        
        let snap = try await db.collection("users").document(uid).collection("chats")
            .order(by: "lastMessage.sentAt", descending: true)
            .limit(to: 50)
            .getDocuments()
        
        return snap.documents.compactMap { mapUserChat($0) }
    }

    // MARK: - Create / Get
    
    func createOrGetDMThread(uidA: String, uidB: String) async throws -> ChatThread {
        // In new schema, threadId IS the peerUid from my perspective.
        // If I am uidA, threadId is uidB. 
         guard let me = currentUid else { 
            throw NSError(domain: "Semtio", code: 401, userInfo: [NSLocalizedDescriptionKey: "Must be logged in"])
        }
        
        // Determine peer
        let peerUid = (me == uidA) ? uidB : uidA
        
        // Check my chat list
        let myRef = db.collection("users").document(me).collection("chats").document(peerUid)
        let doc = try await myRef.getDocument()
        
        if doc.exists, let t = mapUserChat(doc) { return t }
        
        // Create Initial Metadata (Optimistic)
        // We need peer info (username, avatar) to store it. Ideally we fetch it or it's passed.
        // For now,// I will switch to viewing the serialization file first. message or we fetch peer profile now.
        // Create Initial Metadata (Optimistic)
        // Read from flat user document: users/{peerUid}
        let peerDoc = try await db.collection("users").document(peerUid).getDocument()
        let peerData = peerDoc.data()
        
        let now = FieldValue.serverTimestamp()
        let initialData: [String: Any] = [
            "peerUid": peerUid,
            "peerUsername": peerData?["fullName"] as? String ?? peerData?["displayName"] as? String ?? "",
            "peerAvatarUrl": peerData?["profilePicture"] as? String ?? peerData?["avatarURL"] as? String ?? "",
            "createdAt": now,
            "updatedAt": now,
            "type": "dm",
            "participants": [me, peerUid] as [String]
        ]
        
        try await myRef.setData(initialData, merge: true)
        
        // We also initialize the other side? Not strictly necessary until message sent, 
        // but good for "Empty Chat" to exist? 
        // Usually we only create on first message, but to return a valid ChatThread we create local stub.
        
        let fresh = try await myRef.getDocument()
        return mapUserChat(fresh)!
    }
    
    // Legacy / Group Stub - needed for protocol
    func createThread(participants: [String], type: ChatType) async throws -> ChatThread {
         // Fallback to DM logic if 2 people, else error or stub
         if participants.count == 2 {
             return try await createOrGetDMThread(uidA: participants[0], uidB: participants[1])
         }
         throw NSError(domain: "FirestoreChatRepository", code: 501, userInfo: [NSLocalizedDescriptionKey: "Group chat creation not implemented in client."])
     }
     
     func createOrGetEventThread(eventId: String, title: String, participants: [String]) async throws -> ChatThread {
         // v2.1 Event Group Logic
         let threadId = "grp_event_\(eventId)"
         let docRef = db.collection("dms").document(threadId)
         
        let existing = try await docRef.getDocument()
        
        // Use mapUserChat or custom map for group.
        // Since event threads are still "groups" but stored in "dms" for now (legacy hybrid),
        // we can try to map them using a custom mapper or just standard ChatThread init.
        if existing.exists, let thread = mapDM(existing) {
            return thread
        }
         
         let now = FieldValue.serverTimestamp()
         let data: [String: Any] = [
             "type": "group",
             "participants": participants,
             "preview": ["title": title],
             "createdAt": now,
             "updatedAt": now
         ]
         try await docRef.setData(data, merge: true)
         
         return ChatThread(id: threadId, type: .group, participants: participants, lastMessage: nil, updatedAt: Date(), title: title, unreadCounts: [:])
     }
     
     func createGroupThread(name: String, participantIds: [String], creatorId: String, photoURL: String?) async throws -> String {
         let ref = db.collection("dms").document()
         let now = FieldValue.serverTimestamp()
         
         let data: [String: Any] = [
             "type": "group",
             "participants": participantIds,
             "preview": [
                 "title": name,
                 "photoURL": photoURL ?? ""
             ],
             "createdBy": creatorId,
             "createdAt": now,
             "updatedAt": now
         ]
         
         try await ref.setData(data)
         return ref.documentID
     }

    // MARK: - Messages
    
    func fetchMessages(threadId: String, limit: Int) async throws -> [ChatMessage] {
        guard let me = currentUid else { return [] }
        // threadId in this schema is peerUid
        
        let snap = try await db.collection("users").document(me)
            .collection("chats").document(threadId)
            .collection("messages")
            .order(by: "sentAt")
            .limit(to: limit)
            .getDocuments()
            
        return snap.documents.compactMap(mapMessage)
    }

    func sendMessage(_ m: ChatMessage) async throws {
        guard let me = currentUid else { return }
        // m.threadId is peerUid
        let peerUid = m.threadId 
        
        // Optimize: Fetch my profile to restore metadata if chat was deleted by peer
        // We can cache this or fetch it. For robustness, we fetch.
        let myProfileSnap = try? await db.collection("users").document(me).getDocument()
        let myData = myProfileSnap?.data()
        let myName = myData?["fullName"] as? String ?? myData?["displayName"] as? String ?? "User"
        let myAvatar = myData?["profilePicture"] as? String ?? myData?["avatarURL"] as? String ?? ""
        
        let batch = db.batch()
        let now = FieldValue.serverTimestamp()
        
        // 1. My Copy
        let myChatRef = db.collection("users").document(me).collection("chats").document(peerUid)
        let myMsgRef = myChatRef.collection("messages").document() // auto-id for message
        
        // Prepare data with dictionary + server timestamp
        var msgData = m.dictionary
        msgData["sentAt"] = now // Use the same timestamp var we defined
        msgData["senderId"] = me // Ensure sender is me
        
        batch.setData(msgData, forDocument: myMsgRef)
        
        batch.setData([
            "lastMessage": m.text,
            "lastMessageTimestamp": now,
            "updatedAt": now
        ], forDocument: myChatRef, merge: true)
        
        // 2. Peer Copy
        let peerChatRef = db.collection("users").document(peerUid).collection("chats").document(me)
        let peerMsgRef = peerChatRef.collection("messages").document(myMsgRef.documentID)
        
        batch.setData(msgData, forDocument: peerMsgRef)
        
        // Upsert peer metadata to ensure "Resurrection" works if they deleted the chat
        let peerUpdateData: [String: Any] = [
            "lastMessage": m.text,
            "lastMessageTimestamp": now,
            "updatedAt": now,
            "peerUid": me, // I am the peer for them
            "peerUsername": myName, // Restore title
            "peerAvatarUrl": myAvatar, // Restore avatar
            "participants": [me, peerUid], // Restore participants
            "type": "dm", // Restore type
            "unreadCount": FieldValue.increment(Int64(1)),
            "isDeleted": false, // Un-delete if soft deleted
            "isArchived": false // Un-archive if new message arrives? Usually yes.
        ]
        
        batch.setData(peerUpdateData, forDocument: peerChatRef, merge: true)
        
        try await batch.commit()
    }
    
    // MARK: - Unread / Mutable Actions
    
    func markThreadRead(threadId: String, userId: String) async throws {
        // v2.1: Update the user's local copy unreadCount to 0.
        // Schema: users/{userId}/chats/{threadId}
        
        let chatRef = db.collection("users").document(userId).collection("chats").document(threadId)
        
        // We fundamentally only need to clear unreadCount on our copy.
        // We can also check if it exists to be safe, or just update.
        // If it's a legacy group in "dms", this might fail if we don't check.
        
        let doc = try await chatRef.getDocument()
        if doc.exists {
            try await chatRef.updateData([
                "unreadCount": 0,
                "lastReadAt": FieldValue.serverTimestamp()
            ])
        } else {
            // Fallback for legacy groups or "dms" based chats
            // Try to update unreadCounts map in dms/{threadId}
            try await db.collection("dms").document(threadId).updateData([
                "lastReadAt.\(userId)": FieldValue.serverTimestamp(),
                "unreadCounts.\(userId)": 0
            ])
        }
    }
    
    func muteThread(threadId: String, userId: String) async throws {
        // Implement muting logic (e.g., add to user's mutedThreads collection or update thread doc if schema supports it)
        // For now stubbed as no-op or TODO
    }
    
    func unmuteThread(threadId: String, userId: String) async throws {}
    
    func hideThread(threadId: String, userId: String) async throws {
        // For DM chats in v2.1 schema, update the user's own chat document
        let chatRef = db.collection("users").document(userId).collection("chats").document(threadId)

        // Check if document exists first
        let doc = try await chatRef.getDocument()

        if doc.exists {
            // Update existing document
            try await chatRef.updateData([
                "isHidden": true,
                "hiddenAt": FieldValue.serverTimestamp()
            ])
        } else {
            // Fallback to legacy dms collection for group chats
            try await db.collection("dms").document(threadId).updateData([
                "hiddenBy": FieldValue.arrayUnion([userId])
            ])
        }
    }

    func unhideThread(threadId: String, userId: String) async throws {
        // For DM chats in v2.1 schema, update the user's own chat document
        let chatRef = db.collection("users").document(userId).collection("chats").document(threadId)

        // Check if document exists first
        let doc = try await chatRef.getDocument()

        if doc.exists {
            // Update existing document
            try await chatRef.updateData([
                "isHidden": false,
                "hiddenAt": FieldValue.delete()
            ])
        } else {
            // Fallback to legacy dms collection for group chats
            try await db.collection("dms").document(threadId).updateData([
                "hiddenBy": FieldValue.arrayRemove([userId])
            ])
        }
    }
    
    func archiveThread(threadId: String, userId: String) async throws {
        // v2.1: Update user's own chat document
        let chatRef = db.collection("users").document(userId).collection("chats").document(threadId)
        
        let doc = try await chatRef.getDocument()
        if doc.exists {
             try await chatRef.updateData(["isArchived": true])
        } else {
             // Fallback for legacy group chats in "dms"
             try await db.collection("dms").document(threadId).updateData([
                "archivedBy": FieldValue.arrayUnion([userId])
             ])
        }
    }
    
    func unarchiveThread(threadId: String, userId: String) async throws {
        let chatRef = db.collection("users").document(userId).collection("chats").document(threadId)
        
        let doc = try await chatRef.getDocument()
        if doc.exists {
             try await chatRef.updateData(["isArchived": false])
        } else {
             // Fallback
             try await db.collection("dms").document(threadId).updateData([
                "archivedBy": FieldValue.arrayRemove([userId])
             ])
        }
    }
    
    func deleteThread(threadId: String, userId: String) async throws {
        // "Hard Delete": Delete the user's copy of the chat document and all its messages.
        // Schema: users/{userId}/chats/{threadId} (doc)
        //       : users/{userId}/chats/{threadId}/messages (collection)
        
        let chatRef = db.collection("users").document(userId).collection("chats").document(threadId)
        
        // 1. Delete Messages Subcollection
        // Note: Client SDKs don't support recursive delete natively in one call like Admin SDK.
        // We must fetch and delete unless we use a Callable Function (recommended for production).
        // For client-side implementation:
        
        let messagesRef = chatRef.collection("messages")
        
        // Batch delete loop
        while true {
            let snapshot = try await messagesRef.limit(to: 400).getDocuments()
            guard !snapshot.isEmpty else { break }
            
            let batch = db.batch()
            snapshot.documents.forEach { doc in
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        }
        
        // 2. Delete the Chat Document itself
        try await chatRef.delete()
        
        // Cleanup Legacy if needed (optional)
        // For now, since user wants "backend delete", wiping our copy is sufficient for 1-1.
    }
    
    func hardDeleteThread(threadId: String, userId: String) async throws {
        try await deleteThread(threadId: threadId, userId: userId)
    }


    func setThreadUnread(threadId: String, userId: String, count: Int) async throws {
        let chatRef = db.collection("users").document(userId).collection("chats").document(threadId)
        
        // Similar check: Try to update user copy first
        let doc = try await chatRef.getDocument()
        if doc.exists {
             try await chatRef.updateData(["unreadCount": count])
        } else {
             try await db.collection("dms").document(threadId).updateData([
                "unreadCounts.\(userId)": count
             ])
        }
    }
    
    // MARK: - Real-time
    
    func listenThreads(userId: String, onChange: @escaping ([ChatThread]) -> Void, onError: @escaping (Error) -> Void) -> AnyObject? {
        // v2.1 Listener: users/{uid}/chats
        let query = db.collection("users").document(userId).collection("chats")
            .order(by: "updatedAt", descending: true)
            .limit(to: 50)
            
        return query.addSnapshotListener { snapshot, error in
            if let error = error { onError(error); return }
            guard let docs = snapshot?.documents else { return }
            onChange(docs.compactMap { self.mapUserChat($0) })
        }
    }
    
    func listenMessages(threadId: String, onChange: @escaping ([ChatMessage]) -> Void) -> AnyObject? {
        guard let me = currentUid else { return nil }
        
        let query = db.collection("users").document(me)
            .collection("chats").document(threadId)
            .collection("messages")
            .order(by: "sentAt", descending: false)
            .limit(to: 100)
            
        return query.addSnapshotListener { snapshot, error in
            guard let docs = snapshot?.documents else { return }
            onChange(docs.compactMap(self.mapMessage))
        }
    }
    
    func stopListening(_ token: AnyObject?) {
        (token as? ListenerRegistration)?.remove()
    }

    // MARK: - Mapping
    
    private func mapUserChat(_ doc: DocumentSnapshot) -> ChatThread? {
        guard let d = doc.data() else { return nil }

        let peerUid = d["peerUid"] as? String ?? doc.documentID // docId is peerUid in this schema
        let participants = d["participants"] as? [String] ?? []
        let updated = (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

        // Map last message from fields
        var last: ChatMessage? = nil
        if let text = d["lastMessage"] as? String {
             last = ChatMessage(
                id: "last",
                threadId: peerUid,
                text: text,
                senderId: "", // Not stored in summary usually, or add field
                createdAt: (d["lastMessageTimestamp"] as? Timestamp)?.dateValue() ?? updated
             )
        }

        let unread = d["unreadCount"] as? Int ?? 0

        // Parse hidden/archived states
        let isHidden = d["isHidden"] as? Bool ?? false
        let isArchived = d["isArchived"] as? Bool ?? false
        let isDeleted = d["isDeleted"] as? Bool ?? false
        let isMuted = d["isMuted"] as? Bool ?? false

        // Build arrays for per-user state tracking
        var hiddenBy: [String] = []
        var archivedBy: [String] = []
        var deletedBy: [String] = []
        var mutedBy: [String] = []

        if let uid = currentUid {
            if isHidden { hiddenBy.append(uid) }
            if isArchived { archivedBy.append(uid) }
            if isDeleted { deletedBy.append(uid) }
            if isMuted { mutedBy.append(uid) }
        }

        return ChatThread(
            id: peerUid, // threadId is peerUid
            type: .dm,
            participants: participants,
            lastMessage: last,
            updatedAt: updated,
            title: d["peerUsername"] as? String,
            unreadCounts: [currentUid ?? "": unread],
            archivedBy: isArchived ? [currentUid ?? ""] : [],
            deletedBy: isDeleted ? [currentUid ?? ""] : [],
            mutedBy: isMuted ? [currentUid ?? ""] : [],
            hiddenBy: isHidden ? [currentUid ?? ""] : [],
            photoURL: d["peerAvatarUrl"] as? String
        )
    }

    private func mapMessage(_ doc: QueryDocumentSnapshot) -> ChatMessage? {
        let d = doc.data()
        
        let typeString = d["type"] as? String ?? "text"
        let type = ChatMessageType(rawValue: typeString) ?? .text
        
        var msg = ChatMessage(
            id: doc.documentID,
            threadId: doc.reference.parent.parent!.documentID, // peerUid
            text: d["text"] as? String ?? "",
            senderId: d["senderId"] as? String ?? "",
            createdAt: (d["sentAt"] as? Timestamp)?.dateValue() ?? Date(),
            clientTimestamp: (d["clientTimestamp"] as? Timestamp)?.dateValue(),
            attachmentURL: d["attachmentURL"] as? String,
            type: type
        )
        
        msg.sharedPostId = d["sharedPostId"] as? String
        
        if let previewData = d["postPreview"] as? [String: Any] {
            msg.postPreview = PostSharePreview(
                id: previewData["id"] as? String,
                authorId: previewData["authorId"] as? String,
                authorName: previewData["authorName"] as? String,
                authorUsername: previewData["authorUsername"] as? String,
                authorAvatarURL: previewData["authorAvatarURL"] as? String,
                caption: previewData["caption"] as? String,
                mediaURL: previewData["mediaURL"] as? String,
                aspectRatio: previewData["aspectRatio"] as? Double
            )
        }
        
        // Event Mapping
        msg.sharedEventId = d["sharedEventId"] as? String
        
        if let eventData = d["eventPreview"] as? [String: Any] {
            // Safe unwrap required fields or allow nil if struct is robust?
            // EventSharePreview has non-optional id, title, dateLabel.
            if let id = eventData["id"] as? String,
               let title = eventData["title"] as? String,
               let dateLabel = eventData["dateLabel"] as? String {
                
                msg.eventPreview = EventSharePreview(
                    id: id,
                    title: title,
                    dateLabel: dateLabel,
                    locationName: eventData["locationName"] as? String,
                    coverImageURL: eventData["coverImageURL"] as? String,
                    categoryIcon: eventData["categoryIcon"] as? String,
                    category: eventData["category"] as? String,
                    lat: eventData["lat"] as? Double,
                    lon: eventData["lon"] as? Double
                )
            }
        }
        
        return msg // Replaced return statement
    }
    
    // Legacy Mapper for Event/Group support (dms collection)
    private func mapDM(_ doc: DocumentSnapshot) -> ChatThread? {
        guard let d = doc.data() else { return nil }
        let parts = d["participants"] as? [String] ?? []
        let updated = (d["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
        let typeRaw = d["type"] as? String ?? "dm"

        var last: ChatMessage? = nil
        if let lm = d["lastMessage"] as? [String: Any] {
            last = ChatMessage(
                id: "last",
                threadId: doc.documentID,
                text: lm["text"] as? String ?? "",
                senderId: lm["senderId"] as? String ?? "",
                createdAt: (lm["sentAt"] as? Timestamp)?.dateValue() ?? updated
            )
        }
        
        // Title logic for groups
        var title: String? = nil
        var photoURL: String? = nil
        if let preview = d["preview"] as? [String: Any] {
             title = preview["title"] as? String
             photoURL = preview["photoURL"] as? String
        }

        return ChatThread(
            id: doc.documentID,
            type: typeRaw == "group" ? .group : .dm,
            participants: parts,
            lastMessage: last,
            updatedAt: updated,
            title: title,
            unreadCounts: [:],
            photoURL: photoURL
        )
    }
}
