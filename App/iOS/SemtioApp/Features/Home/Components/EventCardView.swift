//
//  EventCardView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Instagram-style event card for feed display with interaction support.
//

import SwiftUI

struct EventCardView: View {
    let event: Event
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover Image / Placeholder
            ZStack {
                // Gradient background based on category
                LinearGradient(
                    colors: [categoryColor.opacity(0.8), categoryColor.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Category icon
                VStack {
                    Image(systemName: event.category.icon)
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.9))
                    
                    if event.isActive {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("CANLI")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColor.onPrimary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                        .padding(.top, 8)
                    }
                }
            }
            .frame(height: 180)
            .clipped()
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(event.title)
                    .font(AppFont.calloutBold)
                    .foregroundColor(.semtioDarkText)
                    .lineLimit(2)
                
                // Location
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(AppFont.caption)
                        .foregroundColor(.gray)
                    
                    Text(locationText)
                        .font(AppFont.footnote)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                // Date & Time
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(AppFont.caption)
                        .foregroundColor(.semtioPrimary)
                    
                    Text(formattedDateTime)
                        .font(AppFont.footnote)
                        .foregroundColor(.semtioPrimary)
                }
                
                // Participant count
                if event.participantCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        
                        Text("\(event.participantCount) katılımcı")
                            .font(AppFont.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                // Action Buttons
                HStack(spacing: 0) {
                    // Join Button (wired to interactions)
                    JoinActionButton(
                        isJoined: appState.interactions.isJoined(event.id),
                        isLoading: appState.interactions.isJoinLoading(event.id),
                        action: {
                            Task { await appState.interactions.toggleJoin(event: event) }
                        }
                    )
                    
                    // Save Button (wired to saved store with Firestore persistence)
                    SaveActionButton(
                        isSaved: appState.saved.isSaved(event.id),
                        isLoading: appState.saved.isToggling(event.id),
                        action: {
                            Task { await appState.saved.toggleSave(eventId: event.id) }
                        }
                    )
                    
                    // Share Button
                    ActionButton(
                        icon: "square.and.arrow.up",
                        label: "Paylaş",
                        action: { shareEvent() }
                    )
                }
            }
            .padding(12)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Actions
    
    private func shareEvent() {
        ShareService.shared.shareEvent(event)
    }
    
    // MARK: - Computed Properties
    
    private var categoryColor: Color {
        switch event.category {
        case .party: return .purple
        case .sport: return .orange
        case .music: return .pink
        case .food: return .red
        case .meetup: return .blue
        case .other: return .gray
        }
    }
    
    private var locationText: String {
        if let district = event.district, let location = event.locationName {
            return "\(district) • \(location)"
        } else if let district = event.district {
            return district
        } else if let location = event.locationName {
            return location
        }
        return "Konum belirtilmedi"
    }
    
    private var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        
        if Calendar.current.isDateInToday(event.startDate) {
            formatter.dateFormat = "'Bugün' HH:mm"
        } else if Calendar.current.isDateInTomorrow(event.startDate) {
            formatter.dateFormat = "'Yarın' HH:mm"
        } else {
            formatter.dateFormat = "EEE HH:mm"
        }
        
        return formatter.string(from: event.startDate)
    }
}

// MARK: - Join Action Button

private struct JoinActionButton: View {
    let isJoined: Bool
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(height: 18)
                } else {
                    Image(systemName: isJoined ? "checkmark.circle.fill" : "hand.raised.fill")
                        .font(AppFont.headline)
                }
                Text(isJoined ? "Katıldın" : "Katıl")
                    .font(.system(size: 11))
            }
            .foregroundColor(isJoined ? .semtioPrimary : .gray)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
    }
}

// MARK: - Save Action Button

private struct SaveActionButton: View {
    let isSaved: Bool
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(height: 18)
                } else {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(AppFont.headline)
                }
                Text(isSaved ? "Kaydedildi" : "Kaydet")
                    .font(.system(size: 11))
            }
            .foregroundColor(isSaved ? .semtioPrimary : .gray)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
    }
}

// MARK: - Generic Action Button

private struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(AppFont.headline)
                Text(label)
                    .font(.system(size: 11))
            }
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            EventCardView(
                event: Event(
                    id: "1",
                    title: "Yazılım Buluşması & Networking Gecesi",
                    description: nil,
                    startDate: Date().addingTimeInterval(3600 * 2),
                    endDate: nil,
                    locationName: "Kolektif House",
                    semtName: nil,
                    hostUserId: nil,
                    participantCount: 42,
                    coverColorHex: nil,
                    category: .meetup,
                    lat: 0, lon: 0,
                    capacityLimit: nil,
                    tags: [],
                    isFeatured: true,
                    createdBy: "user1",
                    createdAt: Date(),
                    district: "Kadıköy",
                    visibility: .public
                )
            )
            
            EventCardView(
                event: Event(
                    id: "2",
                    title: "Yoga Workshop",
                    description: nil,
                    startDate: Date(),
                    endDate: nil,
                    locationName: "Cihangir Parkı",
                    semtName: nil,
                    hostUserId: nil,
                    participantCount: 15,
                    coverColorHex: nil,
                    category: .sport,
                    lat: 0, lon: 0,
                    capacityLimit: 20,
                    tags: [],
                    isFeatured: false,
                    createdBy: "user2",
                    createdAt: Date(),
                    district: "Beyoğlu",
                    visibility: .public
                )
            )
        }
        .padding()
    }
    .background(AppColor.textSecondary.opacity(0.1))
    .environmentObject(AppState(
        session: SessionManager(),
            theme: AppThemeManager(),
        location: LocationManager()
    ))
}
