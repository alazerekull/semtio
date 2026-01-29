//
//  LocationPickerScreen.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import MapKit
import UIKit

struct PickedLocation: Equatable {
    var coordinate: CLLocationCoordinate2D
    var name: String?
    
    static func == (lhs: PickedLocation, rhs: PickedLocation) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.name == rhs.name
    }
}

struct LocationPickerScreen: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var searchService = LocationSearchService()
    
    // Output callback
    var onSelect: (PickedLocation) -> Void
    
    // iOS 17+ Map Position
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))
    
    // Track current center manually since Position doesn't expose it directly in Binding
    @State private var currentCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784)
    
    @State private var isSearching = false
    @State private var pickedName: String? = "Seçilen Konum"
    
    var body: some View {
        NavigationView {
            ZStack {
                // Map
                Map(position: $position)
                    .onMapCameraChange(frequency: .continuous) { context in
                        currentCenter = context.camera.centerCoordinate
                    }
                    .ignoresSafeArea()

                // Coordinate display overlay (top-center)
                VStack {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(AppColor.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pickedName ?? "Konum Seçiliyor...")
                                .font(AppFont.captionBold)
                                .foregroundColor(AppColor.textPrimary)
                            Text("Lat: \(currentCenter.latitude.formatted(.number.precision(.fractionLength(4)))), Lon: \(currentCenter.longitude.formatted(.number.precision(.fractionLength(4))))")
                                .font(.system(size: 10))
                                .foregroundColor(AppColor.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(Radius.md)
                    .padding()

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .top)

                // Center Pin
                Image(systemName: "mappin")
                    .font(.system(size: 40))
                    .foregroundColor(AppColor.error)
                    .padding(.bottom, 40) // Lift visual center of pin to match coordinate center
                    .shadow(radius: 4)
                
                // Content Overlay
                VStack {
                    // Search Bar
                    VStack(spacing: 0) {
                        TextField("Mekan veya adres ara...", text: $searchService.searchQuery)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding()
                            .background(.ultraThinMaterial)
                        
                        if !searchService.completions.isEmpty {
                            List(searchService.completions, id: \.self) { completion in
                                Button {
                                    selectSearchResult(completion)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(completion.title)
                                            .font(AppFont.bodyBold)
                                            .foregroundColor(AppColor.textPrimary)
                                        Text(completion.subtitle)
                                            .font(AppFont.caption)
                                            .foregroundColor(AppColor.textSecondary)
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .frame(maxHeight: 250)
                            .background(AppColor.surface)
                        }
                    }
                    
                    Spacer()
                    
                    // Select Button
                    Button(action: confirmSelection) {
                        Text("Bu Konumu Seç")
                            .font(AppFont.headline)
                            .foregroundColor(AppColor.onPrimary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(AppColor.primary)
                            .cornerRadius(Radius.md)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Konum Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
        }
    }
    
    private func selectSearchResult(_ completion: MKLocalSearchCompletion) {
        searchService.searchQuery = "" // Hide list
        Task {
            if let item = try? await searchService.search(for: completion) {
                // Determine coordinate safely - item.placemark.coordinate is valid
                let coordinate = item.placemark.coordinate
                
                withAnimation {
                    position = .region(MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                    currentCenter = coordinate
                    pickedName = item.name ?? completion.title
                }
            }
        }
    }
    
    private func confirmSelection() {
        print("🗺️ LocationPicker: confirmSelection tapped")
        print("   Center coordinate: \(currentCenter.latitude), \(currentCenter.longitude)")
        print("   Picked name: \(pickedName ?? "nil")")

        let result = PickedLocation(
            coordinate: currentCenter,
            name: pickedName ?? "Seçilen Konum"
        )

        print("   Created PickedLocation: \(result.coordinate.latitude), \(result.coordinate.longitude)")
        print("   Calling onSelect callback...")

        // Haptic feedback for better UX
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        onSelect(result)

        print("   Callback completed, dismissing sheet")
        dismiss()
    }
}
