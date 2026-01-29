//
//  DirectionsService.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import MapKit

enum DirectionsService {
    static func openMaps(for event: Event) {
        let coordinate = CLLocationCoordinate2D(latitude: event.lat, longitude: event.lon)
        
        // Use standard MKPlacemark init
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = event.title
        
        // Open options: Driving mode by default
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        mapItem.openInMaps(launchOptions: launchOptions)
    }
}
