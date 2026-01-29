//
//  NearbyTodaySection.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct NearbyTodaySection: View {
    let events: [Event]
    
    var todayEvents: [Event] {
        events.filter { event in
            // Check if active and happens today
            event.isActive && Calendar.current.isDateInToday(event.startDate)
        }
    }
    
    var body: some View {
        // Only show if there are events for today
        if !todayEvents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .foregroundColor(.semtioPrimary)
                    Text("Bugün Yakınında")
                        .font(AppFont.title3)
                        .foregroundColor(.semtioDarkText)
                    Spacer()
                }
                .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(todayEvents) { event in
                            NavigationLink(destination: EventDetailScreen(event: event)) {
                                FeaturedEventCard(event: event) // Reusing card style
                                    .frame(width: 260) // Slightly wider
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}
