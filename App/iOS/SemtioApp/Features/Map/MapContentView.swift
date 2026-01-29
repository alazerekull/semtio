//
//  MapContentView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import MapKit

struct MapContentView: View {
    @ObservedObject var viewModel: MapViewModel
    @EnvironmentObject var eventStore: EventStore
    
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            ForEach(eventStore.activeEvents) { event in
                Marker("", coordinate: CLLocationCoordinate2D(latitude: event.lat, longitude: event.lon))
                    .tint(.purple)
            }
        }
        .edgesIgnoringSafeArea(.top)
        .onAppear {
            // Ensure location updates are active
            viewModel.checkLocation()
            position = .region(viewModel.region)
        }
        .onChange(of: viewModel.region.center.latitude) { _, _ in
            withAnimation {
                position = .region(viewModel.region)
            }
        }
    }
}
