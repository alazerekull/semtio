//
//  LocationManager.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var userLocation: CLLocation?
    
    private let manager = CLLocationManager()
    
    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func startUpdating() {
        manager.startUpdatingLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last
    }
}
