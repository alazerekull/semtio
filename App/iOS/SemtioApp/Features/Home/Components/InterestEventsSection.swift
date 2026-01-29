//
//  InterestEventsSection.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct InterestEventsSection: View {
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var userStore: UserStore
    
    @State private var interestEvents: [Event] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
                Text("İlgi Alanlarına Göre")
                    .font(AppFont.title3)
                    .foregroundColor(.semtioDarkText)
                Spacer()
            }
            .padding(.horizontal)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if interestEvents.isEmpty {
                // Empty State
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("İlgi alanlarınıza göre etkinlik bulunamadı")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("Profilinizden ilgi alanlarınızı güncelleyin!")
                        .font(.caption)
                        .foregroundColor(.semtioPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(interestEvents) { event in
                            NavigationLink(destination: EventDetailScreen(event: event)) {
                                FeaturedEventCard(event: event)
                                    .frame(width: 260)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .task {
            await loadInterestEvents()
        }
    }
    
    private func loadInterestEvents() async {
        isLoading = true
        
        // Get user interests
        let interests = userStore.currentUser.interests ?? []
        
        if interests.isEmpty {
            interestEvents = []
            isLoading = false
            return
        }
        
        // Fetch events matching interests
        do {
            let filter = EventFilter.forInterests(interests)
            interestEvents = try await eventStore.repo.fetchEvents(filter: filter)
        } catch {
            print("Failed to load interest events: \(error)")
        }
        
        isLoading = false
    }
}
