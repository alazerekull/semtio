//
//  EventStore.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import Combine
import FirebaseFirestore

final class EventStore: ObservableObject {
    @Published private(set) var events: [Event] = []
    @Published private(set) var activeEvents: [Event] = []
    @Published private(set) var mapEvents: [Event] = [] // Global events for Map
    @Published private(set) var trendingEvents: [Event] = []
    @Published private(set) var boostedEvents: [Event] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // NEW: Filter states
    @Published var selectedCategory: EventCategory? = nil
    @Published var selectedDistrict: String? = nil
    
    let repo: EventRepositoryProtocol
    private var listener: AnyObject?
    private var mapListener: AnyObject?
    
    init(repo: EventRepositoryProtocol) {
        self.repo = repo
    }
    
    deinit {
        stopListening()
        stopListeningMapEvents()
    }
    
    // MARK: - Real-time Listening
    
    /// Starts listening to events with optional district filter (server-side)
    @MainActor
    func startListening() {
        // Prevent duplicate listeners
        if listener != nil {
            print("⚠️ EventStore: listener already attached, skipping")
            return
        }
        
        isLoading = true
        print("🟣 district changed: \(selectedDistrict ?? "nil")")
        
        listener = repo.listenEvents(district: selectedDistrict) { [weak self] events in
            Task { @MainActor in
                self?.events = events
                self?.activeEvents = events.filter { $0.isActive }
                self?.isLoading = false
            }
        } onError: { [weak self] error in
            Task { @MainActor in
                self?.errorMessage = error.localizedDescription
                self?.isLoading = false
            }
        }
    }
    
    /// Starts listening to GLOBAL events for Map (ignoring district filter)
    @MainActor
    func startListeningMapEvents() {
        if mapListener != nil { return }
        
        print("🌍 EventStore: Listening to GLOBAL events for Map")
        mapListener = repo.listenEvents(district: nil) { [weak self] events in
            Task { @MainActor in
                self?.mapEvents = events
            }
        } onError: { error in
            print("❌ Map Listener Error: \(error.localizedDescription)")
        }
    }
    
    func stopListening() {
        repo.stopListening(listener)
        listener = nil
    }
    
    func stopListeningMapEvents() {
        repo.stopListening(mapListener)
        mapListener = nil
    }
    
    /// Sets district filter and rebuilds Firestore listener
    @MainActor
    func setDistrict(_ district: String?) {
        guard selectedDistrict != district else { return }
        
        print("🟣 district changed: \(district ?? "nil") (was: \(selectedDistrict ?? "nil"))")
        selectedDistrict = district
        
        // Rebuild listener with new filter
        stopListening()
        startListening()
    }
    
    // MARK: - Fetch Methods
    
    @MainActor
    func load() async {
        startListening()
    }
    
    @MainActor
    func fetchEvent(eventId: String) async throws -> Event {
        return try await repo.fetchEvent(eventId: eventId)
    }
    
    @MainActor
    func loadTrendingEvents() async {
        do {
            trendingEvents = try await repo.fetchTrending(limit: 10)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func loadBoostedEvents() async {
        do {
            boostedEvents = try await repo.fetchBoostedUpcomingEvents(limit: 5)
        } catch {
            // Silently fail or log for analytics, boost failure shouldn't block app
            print("Failed to load boosted events: \(error)")
        }
    }
    
    @MainActor
    func loadEvents(byCategory category: EventCategory) async {
        isLoading = true
        do {
            // Use new filter-based approach or specific alias if available
            // Protocol defines fetchEvents(filter:), so let's use that
            let filter = EventFilter(category: category)
            events = try await repo.fetchEvents(filter: filter)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    @MainActor
    func loadEvents(byDistrict district: String) async {
        isLoading = true
        do {
            events = try await repo.fetchEvents(byDistrict: district)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    @Published var eventsIndexStatus: String = "Unknown"
    
    // ...
    
    @MainActor
    func loadMyEvents(userId: String) async {
        isLoading = true
        eventsIndexStatus = "Loading..."
        do {
            let myEvents = try await repo.fetchEvents(createdBy: userId)
            // Update only user's events in the list
            events = myEvents
            isLoading = false
            eventsIndexStatus = "OK (\(myEvents.count))"
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            
            let nsError = error as NSError
            if nsError.domain == FirestoreErrorDomain && nsError.code == FirestoreErrorCode.failedPrecondition.rawValue {
                 eventsIndexStatus = "INDEX REQUIRED"
            } else {
                 eventsIndexStatus = "ERROR: \(error.localizedDescription.prefix(10))..."
            }
        }
    }
    
    // MARK: - Filtering (Client-side)
    
    var filteredEvents: [Event] {
        var result = events
        
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        if let district = selectedDistrict {
            result = result.filter { $0.district == district }
        }
        
        return result
    }
    
    var pastEvents: [Event] {
        events.filter { $0.isPast }
    }
    
    // MARK: - Create & Delete
    
    @MainActor
    func create(
        title: String,
        description: String?,
        start: Date,
        end: Date?,
        locationName: String?,
        lat: Double,
        lon: Double,
        category: EventCategory,
        hostUserId: String,
        coverImageURL: String? = nil,
        visibility: EventVisibility = .public,
        capacityLimit: Int? = nil,
        district: String? = nil,
        tags: [String] = [],
        isFeatured: Bool = false,
        // NEW FIELDS
        rules: String? = nil,
        isPaid: Bool = false,
        ticketPrice: Double = 0.0,
        isOnline: Bool = false,
        externalLink: String? = nil
    ) async {
        let new = Event(
            id: UUID().uuidString,
            title: title,
            description: description,
            startDate: start,
            endDate: end,
            locationName: locationName,
            semtName: nil,
            hostUserId: hostUserId,
            participantCount: 0,
            coverColorHex: nil,
            category: category,
            lat: lat,
            lon: lon,
            coverImageURL: coverImageURL,
            capacityLimit: capacityLimit,
            tags: tags,
            isFeatured: isFeatured,
            createdBy: hostUserId,
            createdAt: Date(),
            district: district,
            visibility: visibility,
            status: .published,
            rules: rules,
            isPaid: isPaid,
            ticketPrice: ticketPrice,
            isOnline: isOnline,
            externalLink: externalLink,
            attendees: [hostUserId] // Creator is an attendee
        )
        
        do {
            try await repo.createEvent(new)
            events.append(new)
            activeEvents.append(new)
            mapEvents.append(new)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func update(
        id: String,
        title: String,
        description: String?,
        start: Date,
        end: Date?,
        locationName: String?,
        lat: Double,
        lon: Double,
        category: EventCategory,
        district: String? = nil,
        tags: [String] = [],
        isFeatured: Bool = false,
        visibility: EventVisibility? = nil,
        capacityLimit: Int? = nil
    ) async {
        var updateData: [String: Any] = [
            "title": title,
            "description": description ?? "",
            "date": Timestamp(date: start),
            "endDate": Timestamp(date: end ?? start.addingTimeInterval(3600)),
            "locationName": locationName ?? "",
            "locationLat": lat,
            "locationLng": lon,
            "category": category.rawValue,
            "district": district ?? "",
            "tags": tags,
            "isFeatured": isFeatured
        ]
        
        if let visibility = visibility {
            updateData["visibility"] = visibility.rawValue
        }
        if let limit = capacityLimit {
            updateData["capacityLimit"] = limit
        }
        
        do {
            try await repo.updateEvent(id: id, data: updateData)
            
            // Local update for immediate feedback
            if let index = events.firstIndex(where: { $0.id == id }) {
                var event = events[index]
                event.title = title
                event.description = description
                event.startDate = start
                event.endDate = end ?? start.addingTimeInterval(3600)
                event.locationName = locationName
                event.lat = lat
                event.lon = lon
                event.category = category
                event.district = district
                event.tags = tags
                event.isFeatured = isFeatured
                events[index] = event
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func delete(id: String) async {
        do {
            try await repo.deleteEvent(id: id)
            // Real-time listener will update automatically
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Participation
    
    @Published var isJoining: Bool = false
    @Published var joinedEventIds: Set<String> = []
    
    /// Join an event with atomic participant count increment
    @MainActor
    func joinEvent(eventId: String, userId: String) async -> Bool {
        isJoining = true
        defer { isJoining = false }
        
        do {
            try await repo.joinEvent(eventId: eventId, uid: userId)
            joinedEventIds.insert(eventId)
            
            // Optimistic UI: update local participant count
            if let index = events.firstIndex(where: { $0.id == eventId }) {
                events[index].participantCount += 1
            }
            if let index = activeEvents.firstIndex(where: { $0.id == eventId }) {
                activeEvents[index].participantCount += 1
            }
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    /// Leave an event with atomic participant count decrement
    @MainActor
    func leaveEvent(eventId: String, userId: String) async -> Bool {
        do {
            try await repo.leaveEvent(eventId: eventId, uid: userId)
            joinedEventIds.remove(eventId)
            
            // Optimistic UI: update local participant count
            if let index = events.firstIndex(where: { $0.id == eventId }) {
                events[index].participantCount = max(0, events[index].participantCount - 1)
            }
            if let index = activeEvents.firstIndex(where: { $0.id == eventId }) {
                activeEvents[index].participantCount = max(0, activeEvents[index].participantCount - 1)
            }
            
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    /// Check if user has joined an event
    func isUserJoined(eventId: String, userId: String) async -> Bool {
        // Check local cache first
        if joinedEventIds.contains(eventId) { return true }
        
        do {
            return try await repo.isUserJoined(eventId: eventId, uid: userId)
        } catch {
            return false
        }
    }
    
    /// Load events the user has joined
    @MainActor
    func loadJoinedEvents(userId: String) async {
        do {
            let joined = try await repo.fetchJoinedEvents(uid: userId)
            joinedEventIds = Set(joined.map { $0.id })
        } catch {
            print("Failed to load joined events: \(error)")
        }
    }
    
    // MARK: - Saved Events
    
    @MainActor
    func saveEvent(eventId: String, userId: String) async {
        do {
            try await repo.saveEvent(eventId: eventId, userId: userId)
            // UI feedback?
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func unsaveEvent(eventId: String, userId: String) async {
        do {
            try await repo.unsaveEvent(eventId: eventId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func fetchSavedEvents(userId: String) async throws -> [Event] {
         try await repo.fetchSavedEvents(userId: userId)
    }
    
    // MARK: - Join Requests
    
    @MainActor
    func submitJoinRequest(eventId: String, userId: String, userName: String, userAvatarURL: String?) async -> Bool {
        do {
            try await repo.submitJoinRequest(eventId: eventId, userId: userId, userName: userName, userAvatarURL: userAvatarURL)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func getJoinRequestStatus(eventId: String, userId: String) async -> JoinRequestStatus? {
        do {
            return try await repo.getJoinRequestStatus(eventId: eventId, userId: userId)
        } catch {
            return nil
        }
    }
}
