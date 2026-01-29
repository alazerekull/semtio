//
//  CreateEventViewModel.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import Combine
import CoreLocation
import UIKit

@MainActor
class CreateEventViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var description: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(3600)
    @Published var category: EventCategory = .meetup
    @Published var locationName: String? = nil
    @Published var selectedCoordinate: CLLocationCoordinate2D? = nil
    @Published var selectedImage: UIImage? = nil
    
    // NEW: Privacy & Capacity
    @Published var visibility: EventVisibility = .public
    @Published var hasCapacityLimit: Bool = false
    @Published var capacityLimit: Int = 20
    
    @Published var district: String? = nil
    @Published var semtName: String? = nil
    
    // Editing Mode
    private var eventId: String? = nil
    var isEditing: Bool { eventId != nil }
    
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var shouldDismiss = false
    
    private let eventStore: EventStore
    private let userStore: UserStore
    private let geocoder = CLGeocoder()
    private let imageUploader = ImageUploadService()
    
    init(eventStore: EventStore, userStore: UserStore, event: Event? = nil) {
        self.eventStore = eventStore
        self.userStore = userStore
        
        if let event = event {
            self.eventId = event.id
            self.title = event.title
            self.description = event.description ?? ""
            self.startDate = event.startDate
            self.endDate = event.endDate ?? event.startDate.addingTimeInterval(3600)
            self.category = event.category
            self.locationName = event.locationName
            self.selectedCoordinate = CLLocationCoordinate2D(latitude: event.lat, longitude: event.lon)
            self.visibility = event.visibility
            self.district = event.district
            self.semtName = event.semtName
            if let limit = event.capacityLimit, limit > 0 {
                self.hasCapacityLimit = true
                self.capacityLimit = limit
            }
        }
    }
    
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedCoordinate != nil
    }
    
    // Computed capacity value for event creation
    var effectiveCapacityLimit: Int? {
        hasCapacityLimit ? capacityLimit : nil
    }
    
    func duplicateLocation(_ location: PickedLocation) {
        print("🔵 duplicateLocation called")
        print("   Input - lat: \(location.coordinate.latitude), lon: \(location.coordinate.longitude)")
        print("   Input - name: \(location.name ?? "nil")")

        // Explicit state updates
        self.selectedCoordinate = location.coordinate
        self.locationName = location.name

        // Force UI refresh
        self.objectWillChange.send()

        print("   After update - selectedCoordinate: \(String(describing: self.selectedCoordinate))")
        print("   After update - locationName: \(self.locationName ?? "nil")")
        print("   isValid now: \(self.isValid)")

        // Trigger reverse geocoding to find district/semt
        Task {
            await performReverseGeocoding(location.coordinate)
        }
    }
    
    private func performReverseGeocoding(_ coordinate: CLLocationCoordinate2D) async {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                // District (İlçe) -> subAdministrativeArea (e.g., "Beyoğlu")
                // Semt (Mahalle) -> thoroughfare or locality
                
                await MainActor.run {
                    self.district = placemark.subAdministrativeArea
                    self.semtName = placemark.thoroughfare ?? placemark.locality
                    
                    print("📍 Reverse Geocoding Result:")
                    print("   District: \(self.district ?? "nil")")
                    print("   Semt: \(self.semtName ?? "nil")")
                }
            }
        } catch {
            print("❌ Reverse geocoding failed: \(error.localizedDescription)")
        }
    }
    
    func createEvent() async {
        print("🚀 createEvent called")

        // Pre-flight validation with specific errors
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Lütfen etkinlik başlığı girin"
            print("❌ Validation failed: Empty title")
            return
        }

        guard let coordinate = selectedCoordinate else {
            errorMessage = "Lütfen konum seçin"
            print("❌ Validation failed: No location selected")
            return
        }

        print("✅ Validation passed")
        print("   Title: \(trimmedTitle)")
        print("   Coordinate: \(coordinate.latitude), \(coordinate.longitude)")
        print("   Category: \(category.rawValue)")
        print("   Visibility: \(visibility.rawValue)")
        print("   Capacity: \(effectiveCapacityLimit?.description ?? "none")")

        isSubmitting = true
        errorMessage = nil

        // Image Upload
        var finalImageURL: String? = nil
        if let image = selectedImage {
            print("📸 Uploading image...")
            do {
                let uid = userStore.currentUser.id
                let path = "events/\(uid)/\(UUID().uuidString).jpg"
                finalImageURL = try await imageUploader.uploadImage(image, path: path)
                print("✅ Image uploaded: \(finalImageURL ?? "nil")")
            } catch {
                self.errorMessage = "Resim yüklenemedi: \(error.localizedDescription)"
                print("❌ Image upload failed: \(error)")
                isSubmitting = false
                return
            }
        }

        print("💾 Creating event in Firestore...")

        if let id = eventId {
            // Update existing event
            await eventStore.update(
                id: id,
                title: trimmedTitle,
                description: description,
                start: startDate,
                end: endDate,
                locationName: locationName ?? "Konum seçilmedi",
                lat: coordinate.latitude,
                lon: coordinate.longitude,
                category: category,
                district: district,
                tags: [],
                isFeatured: false,
                visibility: visibility,
                capacityLimit: effectiveCapacityLimit
            )
        } else {
            // Create new event
            await eventStore.create(
                title: trimmedTitle,
                description: description,
                start: startDate,
                end: endDate,
                locationName: locationName ?? "Konum seçilmedi",
                lat: coordinate.latitude,
                lon: coordinate.longitude,
                category: category,
                hostUserId: userStore.currentUser.id,
                coverImageURL: finalImageURL,
                visibility: visibility,
                capacityLimit: effectiveCapacityLimit,
                district: district,
                tags: [],
                // Default values for new schema fields (not yet in UI)
                rules: nil,
                isPaid: false,
                ticketPrice: 0.0,
                isOnline: false,
                externalLink: nil
            )
        }

        isSubmitting = false

        if let error = eventStore.errorMessage {
            self.errorMessage = "Etkinlik oluşturulamadı: \(error)"
            print("❌ EventStore error: \(error)")
        } else {
            print("✅ Event created successfully!")
            self.shouldDismiss = true
        }
    }
}

