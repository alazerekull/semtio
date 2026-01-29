//
//  DistrictDetailScreen.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct DistrictSummary: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let eventCount: Int
}

struct DistrictDetailScreen: View {
    let district: DistrictSummary
    @EnvironmentObject var eventStore: EventStore
    @State private var events: [Event] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 16) {
                    Image(systemName: district.icon)
                        .font(.system(size: 32))
                        .foregroundColor(.semtioPrimary)
                        .frame(width: 60, height: 60)
                        .background(Color.semtioPrimary.opacity(0.1))
                        .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(district.name)
                            .font(.title2)
                            .bold()
                        Text("\(events.count) etkinlik")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 8)
                
                // Events List
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if events.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Bu semtte henüz etkinlik yok")
                            .foregroundColor(.gray)
                        Text("İlk etkinliği sen oluştur!")
                            .font(.caption)
                            .foregroundColor(.semtioPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(events) { event in
                            NavigationLink(destination: EventDetailScreen(event: event)) {
                                DistrictEventRow(event: event)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.semtioBackground)
        .navigationTitle(district.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadEvents()
        }
    }
    
    private func loadEvents() async {
        isLoading = true
        do {
            events = try await eventStore.repo.fetchEvents(byDistrict: district.name)
        } catch {
            print("Failed to load events for district: \(error)")
        }
        isLoading = false
    }
}

struct DistrictEventRow: View {
    let event: Event
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            Image(systemName: event.category.icon)
                .font(.title2)
                .foregroundColor(.semtioPrimary)
                .frame(width: 48, height: 48)
                .background(Color.semtioPrimary.opacity(0.1))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(AppFont.calloutBold)
                    .foregroundColor(.semtioDarkText)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label(event.timeLabel, systemImage: "clock")
                    if let loc = event.locationName {
                        Label(loc, systemImage: "mappin")
                    }
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 4)
    }
}

// MARK: - Mock Districts

extension DistrictSummary {
    static let mockDistricts: [DistrictSummary] = [
        DistrictSummary(id: "1", name: "Kadıköy", icon: "building.2.fill", eventCount: 12),
        DistrictSummary(id: "2", name: "Beşiktaş", icon: "building.columns.fill", eventCount: 8),
        DistrictSummary(id: "3", name: "Beyoğlu", icon: "theatermasks.fill", eventCount: 15),
        DistrictSummary(id: "4", name: "Şişli", icon: "building.fill", eventCount: 6),
        DistrictSummary(id: "5", name: "Ataşehir", icon: "house.fill", eventCount: 4)
    ]
}
