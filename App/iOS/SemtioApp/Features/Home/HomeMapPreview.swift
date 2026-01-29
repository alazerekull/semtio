//
//  HomeMapPreview.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import MapKit

struct HomeMapPreview: View {
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var location: LocationManager
    @EnvironmentObject var appState: AppState
    @State private var selectedEvent: Event?
    
    // iOS 17+ Map Position
    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    ))
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Yakındaki Etkinlikler")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.semtioDarkText)
                
                Spacer()
                
                NavigationLink(destination: MapScreen()) {
                    Text("Haritayı Aç")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.semtioPrimary)
                }
            }
            .padding(.horizontal)
            
            // Map Preview
            ZStack {
                Map(position: $position) {
                    // Use Annotation for iOS 17+
                    ForEach(eventStore.activeEvents.prefix(10)) { event in
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: event.lat, longitude: event.lon)) {
                            Button {
                                selectedEvent = event
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.semtioPrimary)
                                        .frame(width: 40, height: 40)
                                        .shadow(radius: 4)
                                    
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(AppColor.onPrimary)
                                }
                            }
                        }
                    }
                }
                .frame(height: 300)
                .cornerRadius(20)
                .disabled(true) // Prevent map interaction, only pin taps work
                
                // Overlay gradient and info
                VStack {
                    Spacer()
                    ZStack(alignment: .bottom) {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.6)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 80)
                        
                        HStack {
                            Image(systemName: "map.fill")
                                .foregroundColor(AppColor.onPrimary)
                            Text("Haritada \(eventStore.activeEvents.count) aktif etkinlik var")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColor.onPrimary)
                            Spacer()
                            Text("Görüntüle")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColor.onPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.semtioPrimary)
                                .cornerRadius(12)
                        }
                        .padding()
                    }
                }
                .cornerRadius(20)
                .allowsHitTesting(false)
            }
            .onTapGesture {
                // Navigate to map tab
                appState.selectedTab = .map
            }
            .padding(.horizontal)
        }
        .sheet(item: $selectedEvent) { event in
            EventMapDetailSheet(event: event, onDismiss: { selectedEvent = nil })
                .presentationDetents([.height(400), .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Center map on user location if available
            if let userLocation = location.userLocation {
                position = .region(MKCoordinateRegion(
                    center: userLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
        }
    }
}
