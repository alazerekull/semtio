import Foundation
import FirebaseFirestore
import CoreLocation

struct FirestoreEvent: Identifiable {
    let id: String
    let title: String
    let category: String?
    let city: String?
    let coordinates: EventCoordinates
    let imageUrl: String?
    let date: Timestamp?
    let endDate: Timestamp?
    let isOnline: Bool?
    let isPrivate: Bool?
    let visibility: String?
    let attendees: [String]? // List of user IDs who have joined
    
    // Helper to get CLLocationCoordinate2D for MapKit
    var clLocation: CLLocationCoordinate2D {
        .init(latitude: coordinates.latitude, longitude: coordinates.longitude)
    }
    
    var visibilityEnum: MapEventVisibility {
        guard let visibility = visibility else { return .publicEvent }
        return MapEventVisibility(rawValue: visibility) ?? .publicEvent
    }
}

enum MapEventVisibility: String {
    case publicEvent = "public"
    case requestApproval = "requestApproval"
    case privateEvent = "private"
}

struct EventCoordinates {
    let latitude: Double
    let longitude: Double
}
