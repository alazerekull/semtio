//
//  MapViewModel.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import SwiftUI
import CoreLocation
import Combine
import MapKit

@MainActor
class MapViewModel: ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    // MARK: - Navigation State
    enum MapSheet: Identifiable {
        case districtPicker
        case eventDetail(Event)
        
        var id: String {
            switch self {
            case .districtPicker: return "districtPicker"
            case .eventDetail(let event): return "event_\(event.id)"
            }
        }
    }
    
    @Published var activeSheet: MapSheet?
    
    // MARK: - District & Event State
    @Published var selectedDistrict: District?
    // districtsSheetPresented removed in favor of activeSheet
    
    @Published var events: [Event] = []
    @Published var selectedEvent: Event? {
        didSet {
            if let event = selectedEvent {
                activeSheet = .eventDetail(event)
            }
        }
    }
    
    @Published var isLoadingEvents = false
    @Published var eventsError: String?
    
    // Dependencies
    private var locationManager: LocationManager
    private let eventRepo: EventRepositoryProtocol
    private let districtRepo: DistrictRepositoryProtocol // Assuming protocol exists now
    
    private var cancellables = Set<AnyCancellable>()
    private var hasZoomedToUser: Bool = false
    
    init(locationManager: LocationManager, 
         eventRepo: EventRepositoryProtocol,
         districtRepo: DistrictRepositoryProtocol) {
        self.locationManager = locationManager
        self.eventRepo = eventRepo
        self.districtRepo = districtRepo
        
        // Sync initial state
        self.authorizationStatus = locationManager.authorizationStatus
        
        // Observe status
        locationManager.$authorizationStatus
            .receive(on: RunLoop.main)
            .assign(to: \.authorizationStatus, on: self)
            .store(in: &cancellables)
            
        // Observe location for initial zoom
        locationManager.$userLocation
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
            .store(in: &cancellables)
    }
    
    func checkLocation() {
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdating()
        }
    }
    
    func requestPermission() {
        locationManager.requestPermission()
    }
    
    // MARK: - District Selection
    
    func didSelectDistrict(_ district: District) {
        selectedDistrict = district
        activeSheet = nil // Close sheet
        
        // Animate Map
        withAnimation(.easeInOut(duration: 1.0)) {
            region = MKCoordinateRegion(
                center: district.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            )
        }
        
        Task { await loadEvents() }
    }
    
    func loadEvents() async {
        isLoadingEvents = true
        eventsError = nil
        
        do {
            if let districtName = selectedDistrict?.name {
                let result = try await eventRepo.fetchEvents(byDistrict: districtName)
                self.events = result
            } else {
                // Return all active events if no district selected
                let result = try await eventRepo.fetchActiveEvents()
                self.events = result
            }
        } catch {
            print("❌ Failed to load events: \(error)")
            self.eventsError = "Etkinlikler yüklenemedi."
            self.events = []
        }
        
        isLoadingEvents = false
    }
    
    // MARK: - Event Actions
    
    func join(event: Event, userId: String) async {
        do {
            try await eventRepo.joinEvent(eventId: event.id, uid: userId)
            // UI update handled by listener or manual refresh
        } catch {
            print("❌ Join failed: \(error)")
        }
    }
    
    // MARK: - Private
    
    private func handleLocationUpdate(_ location: CLLocation) {
        guard !hasZoomedToUser else { return }
        
        self.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        hasZoomedToUser = true
        
        // Optional: auto-select district based on location
    }
}
