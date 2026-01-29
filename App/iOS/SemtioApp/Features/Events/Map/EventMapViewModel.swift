//
//  EventMapViewModel.swift
//  SemtioApp
//
//  Created for MapKit Integration
//

import SwiftUI
import MapKit
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class EventMapViewModel: ObservableObject {
    @Published var events: [FirestoreEvent] = []
    @Published var selectedEvent: FirestoreEvent?
    
    // Default region (Istanbul as requested fallback)
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    private let repository: MapEventRepository
    private let db = Firestore.firestore() // To fetch basic user info if needed
    
    @Published var currentUser: UserLite?
    @Published var isJoining = false
    @Published var joinError: String?
    @Published var joinSuccessMessage: String?
    
    init(repository: MapEventRepository = MapFirestoreEventRepository()) {
        self.repository = repository
        fetchCurrentUser()
    }
    
    private func fetchCurrentUser() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        Task {
            do {
                let snapshot = try await db.collection("users").document(uid).getDocument()
                if let d = snapshot.data() {
                    self.currentUser = UserLite(
                        id: uid,
                        fullName: d["fullName"] as? String ?? "",
                        username: d["username"] as? String ?? "",
                        avatarURL: d["profilePicture"] as? String
                    )
                }
            } catch {
                print("Error fetching user for map: \(error)")
            }
        }
    }
    
    func joinEvent(event: FirestoreEvent) async {
        guard let user = currentUser else { return }
        isJoining = true
        joinError = nil
        
        do {
            if event.visibilityEnum == .requestApproval {
                try await repository.submitJoinRequest(eventId: event.id, user: user)
                joinSuccessMessage = "Katılım isteği gönderildi"
            } else {
                try await repository.joinEvent(eventId: event.id, user: user)
                joinSuccessMessage = "Etkinliğe katıldın!"
                // Refresh local state to update UI immediately
                // In real app, we might just mutate the local event model to show "Joined" state
                if let index = events.firstIndex(where: { $0.id == event.id }) {
                    var updatedAttendees = events[index].attendees ?? []
                    updatedAttendees.append(user.id)
                    // Create a mutated copy (requires struct mutation or var)
                    // For now, reload or just accept the sheet will close. 
                    // Let's close sheet on success.
                }
            }
            // Close sheet after short delay or let View handle it
             try? await Task.sleep(nanoseconds: 1_000_000_000)
             selectedEvent = nil // Close sheet
        } catch {
            joinError = error.localizedDescription
        }
        
        isJoining = false
    }

    func load() async {
        print("📍 ViewModel: Loading events...")
        do {
            let fetchedEvents = try await repository.fetchEventsForMap()
            print("📍 ViewModel: Received \(fetchedEvents.count) events from repo.")
            self.events = fetchedEvents
            
            if fetchedEvents.isEmpty {
                print("📍 ViewModel: Warning - Event list is empty.")
            } else {
                updateRegionToFitAllPins()
            }
        } catch {
            print("❌ ViewModel: Error loading map events: \(error)")
        }
    }
    
    private func updateRegionToFitAllPins() {
        guard !events.isEmpty else { return }
        
        var minLat = 90.0
        var maxLat = -90.0
        var minLon = 180.0
        var maxLon = -180.0
        
        for event in events {
            let lat = event.coordinates.latitude
            let lon = event.coordinates.longitude
            
            if lat < minLat { minLat = lat }
            if lat > maxLat { maxLat = lat }
            if lon < minLon { minLon = lon }
            if lon > maxLon { maxLon = lon }
        }
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        let spanLat = abs(maxLat - minLat) * 1.5 // 1.5x padding
        let spanLon = abs(maxLon - minLon) * 1.5
        
        // Minimum span to avoid zooming in too much on a single pin
        let minSpan = 0.01
        
        self.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: max(spanLat, minSpan), longitudeDelta: max(spanLon, minSpan))
        )
    }
}
