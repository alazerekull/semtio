//
//  FeaturedEventsSection.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct FeaturedEventsSection: View {
    let events: [Event]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Öne Çıkan Etkinlikler")
                    .font(AppFont.title3)
                    .foregroundColor(.semtioDarkText)
                Spacer()
            }
            .padding(.horizontal)
            
            if events.isEmpty {
                EmptyFeaturedState()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(events) { event in
                            NavigationLink(destination: EventDetailScreen(event: event)) {
                                FeaturedEventCard(event: event)
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

struct FeaturedEventCard: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category badge
            HStack {
                Image(systemName: event.category.icon)
                    .font(AppFont.caption)
                Text(event.category.localizedName)
                    .font(AppFont.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.semtioPrimary.opacity(0.15))
            .foregroundColor(.semtioPrimary)
            .cornerRadius(12)
            
            Text(event.title)
                .font(AppFont.calloutBold)
                .foregroundColor(.semtioDarkText)
                .lineLimit(2)
            
            HStack(spacing: 4) {
                Image(systemName: "mappin.circle.fill")
                    .font(AppFont.caption)
                    .foregroundColor(.gray)
                Text(event.locationName ?? "Konum")
                    .font(AppFont.footnote)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(AppFont.caption)
                    .foregroundColor(.semtioPrimary)
                Text("\(event.dayLabel), \(event.timeLabel)")
                    .font(AppFont.footnote)
                    .foregroundColor(.semtioPrimary)
            }
        }
        .frame(width: 200)
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

struct EmptyFeaturedState: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.slash")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.3))
            Text("Şu an öne çıkan etkinlik yok")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.white.opacity(0.5))
        .cornerRadius(20)
        .padding(.horizontal)
    }
}
