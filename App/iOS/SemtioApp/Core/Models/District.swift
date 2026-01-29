//
//  District.swift
//  SemtioApp
//
//  Created for Semtio Map Refactor.
//

import Foundation
import CoreLocation

struct District: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let centerLat: Double
    let centerLng: Double
    var radiusMeters: Double? = 2000
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng)
    }
}
