import Foundation
import FirebaseFirestore

protocol MapEventRepository {
    func fetchEventsForMap() async throws -> [FirestoreEvent]
    func joinEvent(eventId: String, user: UserLite) async throws
    func submitJoinRequest(eventId: String, user: UserLite) async throws
}

final class MapFirestoreEventRepository: MapEventRepository {
    private let db = Firestore.firestore()
    
    func fetchEventsForMap() async throws -> [FirestoreEvent] {
        print("📍 MapRepo: Fetching events for map...")
        // Fetch all recent events first, filter in memory to handle legacy data (missing isOnline field)
        let snapshot = try await db.collection("events")
            .limit(to: 50) 
            .getDocuments()
            
        print("📍 MapRepo: Fetched \(snapshot.documents.count) raw documents.")
        
        let events = snapshot.documents.compactMap { doc -> FirestoreEvent? in
            let d = doc.data()
            let id = doc.documentID
            
            // Debug parsing
            guard let title = d["title"] as? String else {
                print("⚠️ MapRepo: Event \(id) missing title")
                return nil
            }
            
            guard 
                let coords = d["coordinates"] as? [String: Any],
                let lat = coords["latitude"] as? Double,
                let lon = coords["longitude"] as? Double
            else {
                print("⚠️ MapRepo: Event \(id) (\(title)) missing valid coordinates. Data: \(d["coordinates"] ?? "nil")")
                return nil
            }
            
            // SUCCESS
            return FirestoreEvent(
                id: id,
                title: title,
                category: d["category"] as? String,
                city: d["city"] as? String,
                coordinates: EventCoordinates(latitude: lat, longitude: lon),
                imageUrl: d["imageUrl"] as? String,
                date: d["date"] as? Timestamp,
                endDate: d["endDate"] as? Timestamp,
                isOnline: d["isOnline"] as? Bool,
                isPrivate: d["isPrivate"] as? Bool,
                visibility: d["visibility"] as? String,
                attendees: d["attendees"] as? [String]
            )
        }
        
        print("📍 MapRepo: Successfully parsed \(events.count) events.")
        
        // Memory filter:
        // 1. Hide Online Events
        // 2. Hide Private/Invite-Only Events
        let mapEvents = events.filter { event in
            // Filter Online
            if let isOnline = event.isOnline, isOnline == true {
                return false
            }
            
            // Filter Private (Sadece Davetliler)
            // Check implicit boolean
            if let isPrivate = event.isPrivate, isPrivate == true {
                return false
            }
            // Check explicit enum string
            if let vis = event.visibility, vis == "private" {
                return false
            }
            
            return true
        }
        
        print("📍 MapRepo: Returning \(mapEvents.count) events after online filter.")
        return mapEvents
    }
    
    func joinEvent(eventId: String, user: UserLite) async throws {
        let eventRef = db.collection("events").document(eventId)
        let userRef = db.collection("users").document(user.id)
        
        let batch = db.batch()
        
        // 1. Add to event attendees/usersJoined
        let userJoinedData: [String: Any] = [
            "uid": user.id,
            "username": user.username,
            "profilePicture": user.avatarURL ?? ""
        ]
        
        batch.updateData([
            "attendees": FieldValue.arrayUnion([user.id]),
            "usersJoined": FieldValue.arrayUnion([userJoinedData])
        ], forDocument: eventRef)
        
        // 2. Add to user joinedEvents
        let joinedEventRef = userRef.collection("joinedEvents").document(eventId)
        batch.setData([
            "joinedAt": FieldValue.serverTimestamp()
        ], forDocument: joinedEventRef)
        
        try await batch.commit()
    }
    
    func submitJoinRequest(eventId: String, user: UserLite) async throws {
        let batch = db.batch()
        
        // 1. Write to event's subcollection (for event owner to see)
        let eventRequestRef = db.collection("events").document(eventId).collection("join_requests").document(user.id)
        let requestData: [String: Any] = [
            "id": user.id, // request ID (using user ID)
            "eventId": eventId,
            "userId": user.id,
            "guestUid": user.id,
            "userName": user.username,
            "userAvatarURL": user.avatarURL ?? "",
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp()
        ]
        batch.setData(requestData, forDocument: eventRequestRef)
        
        // 2. Write to user's private subcollection (for "Pending" tab to query without Index)
        let userRequestRef = db.collection("users").document(user.id).collection("sent_requests").document(eventId)
        let myRequestData: [String: Any] = [
            "eventId": eventId,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp()
        ]
        batch.setData(myRequestData, forDocument: userRequestRef)
        
        try await batch.commit()
    }
}
