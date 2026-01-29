//
//  MapScreen.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import MapKit

struct MapScreen: View {
    @StateObject private var viewModel = EventMapViewModel()
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $viewModel.region, showsUserLocation: true, annotationItems: viewModel.events) { event in
                MapAnnotation(coordinate: event.clLocation) {
                    Button {
                        viewModel.selectedEvent = event
                    } label: {
                        VStack(spacing: 4) {
                            if let imageUrl = event.imageUrl, let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 36, height: 36)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                            .shadow(radius: 2)
                                    }
                                }
                            }
                            
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                                .background(Color.white.clipShape(Circle()))
                        }
                    }
                }
            }
            .ignoresSafeArea()
            
            // Loading Overlay
            if viewModel.events.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Etkinlikler Yükleniyor...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(10)
                    Spacer()
                }
            }
        }
        .sheet(item: $viewModel.selectedEvent) { event in
            EventPreviewSheet(event: event, viewModel: viewModel) {
                viewModel.selectedEvent = nil
            }
        }
        .task {
            print("📍 MapScreen: Task started, loading view model...")
            await viewModel.load()
        }
    }
}


