import Foundation
import FirebaseFirestore
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

//
// FIREBASE SCHEMA (Your Structure):
// - Path: /events/{eventId}
// - Fields: id, title, description, rules, category, city, locationName, coordinates, capacity,
//           minAge, maxAge, isOnline, isPrivate, isPaid, ticketPrice, externalLink, imageUrl,
//           creatorId, createdAt, date (start), endDate, attendees[], usersJoined[]
// - Subcollection: /events/{eventId}/messages/{messageId}
//

final class FirestoreEventRepository: EventRepository {
    private let db = Firestore.firestore()

    // MARK: - Fetch

    func fetchEvents() async throws -> [Event] {
        let snap = try await db.collection("events")
            .whereField("isPrivate", isEqualTo: false)
            // .order(by: "date", descending: true) -- Removed for No-Index
            .limit(to: 50)
            .getDocuments()

        return snap.documents.compactMap(mapDocumentToEvent).sorted { $0.startDate > $1.startDate }
    }

    func fetchEvent(eventId: String) async throws -> Event {
        let doc = try await db.collection("events").document(eventId).getDocument()
        guard let e = mapDocumentToEvent(doc) else {
            throw NSError(domain: "Semtio", code: 404)
        }
        return e
    }

    func fetchActiveEvents() async throws -> [Event] {
        let now = Date()
        let snap = try await db.collection("events")
            .whereField("isPrivate", isEqualTo: false)
            // .whereField("endDate", isGreaterThan: Timestamp(date: now)) -- Removed for No-Index
            // .order(by: "endDate") -- Removed
            .limit(to: 50)
            .getDocuments()

        let validEvents = snap.documents.compactMap(mapDocumentToEvent).filter { event in
            // Manual filter
            if let end = event.endDate { return end > now }
            return event.startDate > now
        }
        
        return validEvents.sorted { ($0.endDate ?? Date.distantPast) < ($1.endDate ?? Date.distantPast) }
    }

    func fetchTrending(limit: Int = 10) async throws -> [Event] {
        // Your schema doesn't have metrics.score - sort by date or attendees count
        let snap = try await db.collection("events")
            .whereField("isPrivate", isEqualTo: false)
            // .order(by: "date", descending: true) -- Removed
            .limit(to: limit)
            .getDocuments()

        return snap.documents.compactMap(mapDocumentToEvent).sorted { $0.startDate > $1.startDate }
    }

    func fetchEvents(byDistrict district: String) async throws -> [Event] {
        let now = Date()
        let snap = try await db.collection("events")
            .whereField("isPrivate", isEqualTo: false)
            .whereField("city", isEqualTo: district)
            // .whereField("endDate", isGreaterThan: Timestamp(date: now)) -- Removed
            // .order(by: "endDate") -- Removed
            .limit(to: 50)
            .getDocuments()

        let validEvents = snap.documents.compactMap(mapDocumentToEvent).filter { event in
             if let end = event.endDate { return end > now }
             return event.startDate > now
        }

        return validEvents.sorted { ($0.endDate ?? Date.distantPast) < ($1.endDate ?? Date.distantPast) }
    }

    func fetchEvents(bySemt semt: String) async throws -> [Event] {
        // Using city field since your schema uses city
        let snap = try await db.collection("events")
            .whereField("isPrivate", isEqualTo: false)
            .whereField("city", isEqualTo: semt)
            // .order(by: "date", descending: true) -- Removed
            .limit(to: 20)
            .getDocuments()

        return snap.documents.compactMap(mapDocumentToEvent).sorted { $0.startDate > $1.startDate }
    }

    func fetchEvents(createdBy uid: String) async throws -> [Event] {
        let snap = try await db.collection("events")
            .whereField("creatorId", isEqualTo: uid)
            // .order(by: "createdAt", descending: true) -- Removed to avoid composite index
            .limit(to: 50)
            .getDocuments()

        let events = snap.documents.compactMap(mapDocumentToEvent)
        return events.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Flexible Filter

    func fetchEvents(filter: EventFilter) async throws -> [Event] {
        var query = db.collection("events")
            .whereField("isPrivate", isEqualTo: false)

        let now = Date()

        // Apply filters
        if let cat = filter.category {
            query = query.whereField("category", isEqualTo: cat.rawValue)
        }

        if let dist = filter.district {
            query = query.whereField("city", isEqualTo: dist)
        }

        // Default time sort - future events handled manually below
        // query = query.whereField("endDate", isGreaterThan: Timestamp(date: now)) -- Removed
                     // .order(by: "endDate") -- Removed

        if let limit = filter.limit {
            query = query.limit(to: limit)
        } else {
            query = query.limit(to: 50)
        }

        let snap = try await query.getDocuments()
        let all = snap.documents.compactMap(mapDocumentToEvent)
        let filtered = all.filter { event in
            if let end = event.endDate { return end > now }
            return event.startDate > now
        }
        return filtered.sorted { ($0.endDate ?? Date.distantPast) < ($1.endDate ?? Date.distantPast) }
    }

    // MARK: - Feed Pagination

    func fetchFeedEvents(mode: FeedMode, limit: Int) async throws -> FeedPageResult {
        let events: [Event]
        switch mode {
        case .upcoming:
            events = try await fetchActiveEvents()
        case .featured:
            events = try await fetchTrending(limit: limit)
        case .nearby:
            events = []
        case .forYou:
            events = try await fetchEvents()
        }
        return FeedPageResult(events: events, hasMore: false)
    }

    func resetFeedCursor(mode: FeedMode) {
        // No-op for stateless implementation
    }

    // MARK: - Create / Update / Delete

    func createEvent(_ event: Event) async throws {
        let endAt = event.endDate ?? event.startDate.addingTimeInterval(7200)

        let data: [String: Any] = [
            "id": event.id,
            "title": event.title,
            "description": event.description ?? "",
            "rules": event.rules ?? "",
            "category": event.category.rawValue,
            "city": event.district ?? "",
            "locationName": event.locationName ?? "",
            "coordinates": [
                "latitude": event.lat,
                "longitude": event.lon
            ],
            "capacity": event.capacityLimit ?? 0,

            // Dates
            "date": Timestamp(date: event.startDate),
            "endDate": Timestamp(date: endAt),
            "createdAt": FieldValue.serverTimestamp(),

            // Boolean flags
            "isOnline": event.isOnline,
            "isPrivate": event.visibility == .private,
            // Explicit visibility mode persistence
            "visibility": event.visibility.rawValue,
            
            "isPaid": event.isPaid,
            "ticketPrice": event.ticketPrice,

            "externalLink": event.externalLink ?? "",
            "imageUrl": event.coverImageURL ?? "",

            "creatorId": event.createdBy,
            "attendees": event.attendees,
            "usersJoined": []
        ]

        try await db.collection("events").document(event.id).setData(data)
    }

    func updateEvent(id: String, data: [String: Any]) async throws {
        try await db.collection("events").document(id).updateData(data)
    }

    func deleteEvent(id: String) async throws {
        try await db.collection("events").document(id).delete()
    }

    // MARK: - Membership

    func joinEvent(eventId: String, uid: String) async throws {
        // Add user to attendees array and usersJoined
        let eventRef = db.collection("events").document(eventId)

        // Get current user info for usersJoined
        let userDoc = try? await db.collection("users").document(uid).getDocument()
        let userData = userDoc?.data()

        let userJoinedData: [String: Any] = [
            "uid": uid,
            "username": userData?["username"] as? String ?? "",
            "profilePicture": userData?["profilePicture"] as? String ?? ""
        ]

        try await eventRef.updateData([
            "attendees": FieldValue.arrayUnion([uid]),
            "usersJoined": FieldValue.arrayUnion([userJoinedData])
        ])

        // Also add to user's joinedEvents (users/{uid}/joinedEvents/{eventId})
        try await db.collection("users").document(uid).collection("joinedEvents").document(eventId).setData([
            "joinedAt": FieldValue.serverTimestamp()
        ])
    }

    func leaveEvent(eventId: String, uid: String) async throws {
        let eventRef = db.collection("events").document(eventId)

        // Remove from attendees
        try await eventRef.updateData([
            "attendees": FieldValue.arrayRemove([uid])
        ])

        // Note: Removing from usersJoined array of objects is more complex,
        // would need to read/modify/write or use Cloud Function

        // Remove from user's joinedEvents
        try await db.collection("users").document(uid).collection("joinedEvents").document(eventId).delete()
    }

    func isUserJoined(eventId: String, uid: String) async throws -> Bool {
        let doc = try await db.collection("events").document(eventId).getDocument()
        let attendees = doc.data()?["attendees"] as? [String] ?? []
        return attendees.contains(uid)
    }

    func fetchJoinedEvents(uid: String) async throws -> [Event] {
        let snap = try await db.collection("users")
            .document(uid)
            .collection("joinedEvents")
            .order(by: "joinedAt", descending: true)
            .getDocuments()

        let ids = snap.documents.map { $0.documentID }
        guard !ids.isEmpty else { return [] }

        let batches = stride(from: 0, to: ids.count, by: 10).map {
            Array(ids[$0..<min($0+10, ids.count)])
        }

        var result: [Event] = []
        for b in batches {
            let s = try await db.collection("events")
                .whereField(FieldPath.documentID(), in: b)
                .getDocuments()
            result.append(contentsOf: s.documents.compactMap(mapDocumentToEvent))
        }

        return result
    }

    func fetchPendingJoinedEvents(uid: String) async throws -> [Event] {
        // Strategy: Query /users/{uid}/sent_requests to avoid Collection Group Index requirements.
        
        let snapshot = try await db.collection("users").document(uid)
            .collection("sent_requests")
            .whereField("status", isEqualTo: "pending")
            .getDocuments()
        
        let eventIds = snapshot.documents.compactMap { $0.documentID } // Document ID is eventId
        
        if eventIds.isEmpty {
            return []
        }
        
        // Fetch events in batches
        var events: [Event] = []
        let uniqueIds = Array(Set(eventIds))
        
        // Use manual logic if chunked isn't available or just inline iteration
        // Since we removed 'chunked' to fix compilation, we implement simple batching here
        let batchSize = 10
        for i in stride(from: 0, to: uniqueIds.count, by: batchSize) {
            let end = min(i + batchSize, uniqueIds.count)
            let chunk = Array(uniqueIds[i..<end])
            
            do {
                let chunkSnapshot = try await db.collection("events")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                
                let loadedEvents = chunkSnapshot.documents.compactMap { try? mapDocumentToEvent($0) }
                events.append(contentsOf: loadedEvents)
            } catch {
                print("Error loading batch events: \(error)")
            }
        }
        
        return events
    }

    // MARK: - Real-time

    func listenEvents(district: String?, onChange: @escaping ([Event]) -> Void, onError: @escaping (Error) -> Void) -> AnyObject? {
        let now = Timestamp(date: Date())
        var query = db.collection("events")
            .whereField("isPrivate", isEqualTo: false)

        if let district = district, !district.isEmpty {
            query = query.whereField("city", isEqualTo: district)
        }

        // query = query.whereField("endDate", isGreaterThan: now) -- Removed
                     // .order(by: "endDate") -- Removed
        query = query.limit(to: 200) // Increased from 50 to 200 to capture upcoming events despite no-index

        print("📡 Firestore: ListenEvents started (district: \(district ?? "Global"))")
        return query.addSnapshotListener { snapshot, error in
            if let error = error {
                print("❌ Firestore Listen Error: \(error.localizedDescription)")
                onError(error)
                return
            }
            guard let docs = snapshot?.documents else { return }
            let events = docs.compactMap { self.mapDocumentToEvent($0) }
            
            // Debugging
            print("📡 Firestore: Fetched \(events.count) raw events")
            
            let valid = events.filter { event in
                if let end = event.endDate { return end > now.dateValue() }
                return event.startDate > now.dateValue()
            }
            
            print("📡 Firestore: \(valid.count) events valid after date filter (Date > \(now.dateValue()))")
            
            onChange(valid.sorted { ($0.endDate ?? Date.distantPast) < ($1.endDate ?? Date.distantPast) })
        }
    }

    func stopListening(_ token: AnyObject?) {
        (token as? ListenerRegistration)?.remove()
    }

    // MARK: - Premium / Other Stubs

    func boostEvent(eventId: String) async throws -> Date { return Date() }
    func fetchBoostedUpcomingEvents(limit: Int) async throws -> [Event] { return [] }

    func saveEvent(eventId: String, userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "savedEventIds": FieldValue.arrayUnion([eventId])
        ])
    }

    func unsaveEvent(eventId: String, userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "savedEventIds": FieldValue.arrayRemove([eventId])
        ])
    }

    func isEventSaved(eventId: String, userId: String) async throws -> Bool {
        let doc = try await db.collection("users").document(userId).getDocument()
        let savedIds = doc.data()?["savedEventIds"] as? [String] ?? []
        return savedIds.contains(eventId)
    }

    func fetchSavedEvents(userId: String) async throws -> [Event] {
        let doc = try await db.collection("users").document(userId).getDocument()
        let savedIds = doc.data()?["savedEventIds"] as? [String] ?? []

        guard !savedIds.isEmpty else { return [] }

        var events: [Event] = []
        let batches = stride(from: 0, to: savedIds.count, by: 10).map {
            Array(savedIds[$0..<min($0+10, savedIds.count)])
        }

        for batch in batches {
            let snap = try await db.collection("events")
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments()
            events.append(contentsOf: snap.documents.compactMap(mapDocumentToEvent))
        }

        return events
    }

    func cancelEvent(eventId: String) async throws {
        try await deleteEvent(id: eventId)
    }

    func submitJoinRequest(eventId: String, userId: String, userName: String, userAvatarURL: String?) async throws {
        // Path: /events/{eventId}/join_requests/{userId}
        // Using userId as document ID for 1:1 relationship
        let ref = db.collection("events").document(eventId).collection("join_requests").document(userId)

        let data: [String: Any] = [
            "id": userId,
            "eventId": eventId,
            "userId": userId,
            "guestUid": userId, // New standard field
            "userName": userName,
            "userAvatarURL": userAvatarURL ?? "",
            "status": JoinRequestStatus.pending.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]

        try await ref.setData(data)
    }

    func respondToJoinRequest(eventId: String, requestId: String, approve: Bool, note: String?) async throws {
        // requestId is guestUid in new schema
        let guestUid = requestId 
        let ref = db.collection("events").document(eventId).collection("join_requests").document(guestUid)

        _ = try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            let doc: DocumentSnapshot
            do {
                doc = try transaction.getDocument(ref)
            } catch let nsError as NSError {
                errorPointer?.pointee = nsError
                return nil
            }
            
            guard doc.exists else { return nil }
            
            let status: JoinRequestStatus = approve ? .approved : .rejected
            var updateData: [String: Any] = [
                "status": status.rawValue,
                "respondedAt": FieldValue.serverTimestamp()
            ]
            if let note = note { updateData["responseNote"] = note }
            
            transaction.updateData(updateData, forDocument: ref)
            
            // 2. Update user's sent_requests (for Pending tab sync)
            let sentRequestRef = self.db.collection("users").document(guestUid).collection("sent_requests").document(eventId)
            // Check if exists first? Or just update. If it doesn't exist (legacy), this might fail if using update. 
            // Use set(merge: true) equivalent logic. In transaction, we can just set status.
            // Since we know they sent a request, it should exist. But to be safe, set merge.
            transaction.setData(["status": status.rawValue], forDocument: sentRequestRef, merge: true)
            
            if approve {
                // Add to event attendees
                let eventRef = self.db.collection("events").document(eventId)
                
                // Get user info from request doc to add to usersJoined (denormalized)
                let d = doc.data()
                let userJoinedData: [String: Any] = [
                    "uid": guestUid,
                    "username": d?["userName"] as? String ?? "",
                    "profilePicture": d?["userAvatarURL"] as? String ?? ""
                ]
                
                transaction.updateData([
                    "attendees": FieldValue.arrayUnion([guestUid]),
                    "usersJoined": FieldValue.arrayUnion([userJoinedData])
                ], forDocument: eventRef)
                
                // Add to user joinedEvents
                let userJoinRef = self.db.collection("users").document(guestUid).collection("joinedEvents").document(eventId)
                transaction.setData(["joinedAt": FieldValue.serverTimestamp()], forDocument: userJoinRef)
            }
            return nil
        })
    }

    func fetchPendingJoinRequests(eventId: String) async throws -> [JoinRequest] {
        let snapshot = try await db.collection("events").document(eventId)
            .collection("join_requests")
            .whereField("status", isEqualTo: "pending")
             // .order(by: "createdAt", descending: true) -- Removed
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let d = doc.data()
            guard
                let startId = d["id"] as? String, // guestUid
                let eId = d["eventId"] as? String,
                let uId = d["userId"] as? String,
                let statusRaw = d["status"] as? String,
                let status = JoinRequestStatus(rawValue: statusRaw)
            else { return nil }

            return JoinRequest(
                id: startId,
                eventId: eId,
                userId: uId,
                userName: d["userName"] as? String ?? "",
                userAvatarURL: d["userAvatarURL"] as? String,
                status: status,
                createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                respondedAt: (d["respondedAt"] as? Timestamp)?.dateValue(),
                responseNote: d["responseNote"] as? String
            )
        }
    }

    func getJoinRequestStatus(eventId: String, userId: String) async throws -> JoinRequestStatus? {
        // Path: /events/{eventId}/join_requests/{userId}
        let doc = try await db.collection("events").document(eventId)
            .collection("join_requests").document(userId)
            .getDocument()

        guard doc.exists, let statusRaw = doc.data()?["status"] as? String else {
            return nil
        }

        return JoinRequestStatus(rawValue: statusRaw)
    }

    func createInviteLink(eventId: String) async throws -> String {
        return "semtio://event/\(eventId)"
    }

    func joinWithInvite(token: String) async throws -> String {
        return "event-id-from-token"
    }

    // MARK: - Mapping

    private func mapDocumentToEvent(_ doc: DocumentSnapshot) -> Event? {
        guard let d = doc.data() else { return nil }

        // Attendees mapping
        let attendees = d["attendees"] as? [String] ?? []
        let usersJoinedData = d["usersJoined"] as? [[String: Any]] ?? []
        let usersJoined = usersJoinedData.compactMap { dict -> UserLite? in
            guard let uid = dict["uid"] as? String else { return nil }
            return UserLite(
                id: uid,
                fullName: dict["username"] as? String ?? "",
                username: dict["username"] as? String ?? "",
                avatarURL: dict["profilePicture"] as? String
            )
        }

        // Parse coordinates
        let coords = d["coordinates"] as? [String: Any]
        let lat = coords?["latitude"] as? Double ?? 0
        let lon = coords?["longitude"] as? Double ?? 0
        
        // Visibility Mapping
        let visibility: EventVisibility
        if let vString = d["visibility"] as? String, let v = EventVisibility(rawValue: vString) {
            visibility = v
        } else {
            // Fallback for legacy
            visibility = (d["isPrivate"] as? Bool == true) ? .private : .public
        }

        return Event(
            id: doc.documentID,
            title: d["title"] as? String ?? "",
            description: d["description"] as? String,
            startDate: (d["date"] as? Timestamp)?.dateValue() ?? Date(),
            endDate: (d["endDate"] as? Timestamp)?.dateValue(),
            locationName: d["locationName"] as? String,
            semtName: nil,
            hostUserId: d["creatorId"] as? String,
            participantCount: attendees.count,
            coverColorHex: nil,
            category: EventCategory(rawValue: d["category"] as? String ?? "other") ?? .other,
            lat: lat,
            lon: lon,
            coverImageURL: d["imageUrl"] as? String,
            capacityLimit: d["capacity"] as? Int,
            tags: [],
            isFeatured: false,
            createdBy: d["creatorId"] as? String ?? "",
            createdAt: (d["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            district: d["city"] as? String,
            visibility: visibility,
            status: .published,

            // Schema Fields
            rules: d["rules"] as? String,
            isPaid: d["isPaid"] as? Bool ?? false,
            ticketPrice: d["ticketPrice"] as? Double ?? 0.0,
            isOnline: d["isOnline"] as? Bool ?? false,
            externalLink: d["externalLink"] as? String,
            attendees: attendees,
            usersJoined: usersJoined
        )
    }
    // MARK: - Event Chat
    
    func sendEventMessage(eventId: String, text: String, sender: UserLite) async throws {
        // Subcollection: messages (per schema)
        let ref = db.collection("events").document(eventId).collection("messages").document()
        let data: [String: Any] = [
            "type": "text",
            "text": text,
            "senderId": sender.id,
            "senderName": sender.fullName,
            "senderImage": sender.avatarURL ?? "", // Schema: senderImage
            "isOrganizer": false, // Default
            "timestamp": FieldValue.serverTimestamp()
        ]
        try await ref.setData(data)
    }
    
    func listenEventMessages(eventId: String, onChange: @escaping ([ChatMessage]) -> Void) -> AnyObject? {
        let query = db.collection("events").document(eventId).collection("messages")
            .order(by: "timestamp", descending: false) // Schema: timestamp
            .limit(to: 100)
            
        return query.addSnapshotListener { snapshot, error in
            guard let docs = snapshot?.documents else { return }
            onChange(docs.compactMap { doc in
                let d = doc.data()
                return ChatMessage(
                    id: doc.documentID,
                    threadId: eventId,
                    text: d["text"] as? String ?? "",
                    senderId: d["senderId"] as? String ?? "",
                    createdAt: (d["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                )
            })
        }
    }
}
