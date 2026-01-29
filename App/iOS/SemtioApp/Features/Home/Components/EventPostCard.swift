//
//  EventPostCard.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import MapKit

struct EventPostCard: View {
    let event: Event
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var interactions: EventInteractionStore
    
    @State private var isLiked: Bool = false
    @State private var isSaved: Bool = false
    @State private var creator: AppUser?
    
    // Performance: Computed props
    // We'll trust local state for now as EventInteractionStore might differ from PostInteractionStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // 1. Header (Identical to Post)
            if let creator = creator {
                PostHeaderView(
                    ownerId: creator.id,
                    displayName: creator.username ?? creator.fullName,
                    username: nil, // Display name handles it
                    avatarURL: URL(string: creator.avatarURL ?? ""),
                    timeAgo: timeAgo(event.createdAt),
                    isOwner: creator.id == userStore.currentUser.id,
                    onDelete: {},
                    onBlock: {},
                    onReport: {}
                )
            } else {
                // Skeleton Header
                HStack {
                    Circle().fill(Color.gray.opacity(0.2)).frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 100, height: 14)
                        Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 60, height: 12)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            
            // 2. Main Content (Image + Map Overlay)
            // 2. Main Content (Image + Map Overlay)
            ZStack(alignment: .bottom) {
                NavigationLink(destination: EventDetailScreen(event: event)) {
                    if let coverImageURL = event.coverImageURL, !coverImageURL.isEmpty, let url = URL(string: coverImageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(4/3, contentMode: .fit)
                                    .overlay(
                                        GeometryReader { geometry in
                                            // Mini Map Strip (Bottom 20%)
                                            let mapHeight = geometry.size.height * 0.2
                                            
                                            Group {
                                                if #available(iOS 17.0, *) {
                                                    Map(position: .constant(.region(MKCoordinateRegion(
                                                        center: CLLocationCoordinate2D(latitude: event.lat, longitude: event.lon),
                                                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                                                    )))) {
                                                        Marker("", coordinate: CLLocationCoordinate2D(latitude: event.lat, longitude: event.lon))
                                                            .tint(.red)
                                                    }
                                                    .disabled(true)
                                                } else {
                                                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                                                        center: CLLocationCoordinate2D(latitude: event.lat, longitude: event.lon),
                                                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                                                    )), annotationItems: [event]) { place in
                                                        MapMarker(coordinate: CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon), tint: .red)
                                                    }
                                                    .disabled(true)
                                                }
                                            }
                                            .frame(width: geometry.size.width, height: mapHeight) // Full width
                                            .clipShape(RoundedCornersShape(corners: [.topLeft, .topRight], radius: 12))
                                            .overlay(
                                                RoundedCornersShape(corners: [.topLeft, .topRight], radius: 12)
                                                    .stroke(Color.white, lineWidth: 2)
                                            )
                                            .shadow(radius: 4)
                                            .position(x: geometry.size.width / 2, y: geometry.size.height - (mapHeight / 2)) // Bottom aligned
                                        }
                                    )
                                    .clipped() // Clip image content
                                    .background(Color.black.opacity(0.05))
                            case .failure:
                                fallbackCover
                            case .empty:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                    .aspectRatio(4/3, contentMode: .fit)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        fallbackCover
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 3. Actions & Footer
            VStack(alignment: .leading, spacing: 10) {
                
                // Action Bar
                HStack(spacing: 16) {
                    Button(action: toggleLike) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 24))
                            .foregroundColor(isLiked ? .red : .semtioDarkText)
                            .scaleEffect(isLiked ? 1.1 : 1.0)
                    }
                    
                    NavigationLink(destination: EventDetailScreen(event: event)) {
                        Image(systemName: "bubble.right")
                             .font(AppFont.title2)
                             .foregroundColor(.semtioDarkText)
                    }
                    
                    if let shareURL = event.shareURL {
                        ShareLink(item: shareURL) {
                            Image(systemName: "paperplane")
                                .font(AppFont.title2)
                                .foregroundColor(.semtioDarkText)
                        }
                    } else {
                         Image(systemName: "paperplane")
                             .font(AppFont.title2)
                             .foregroundColor(.semtioDarkText)
                    }
                    
                    Spacer()
                    
                    Button(action: toggleSave) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(AppFont.title2)
                            .foregroundColor(.semtioDarkText)
                    }
                }
                .padding(.top, 4)
                
                // Styled Event Details (Like Chat Bubble)
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 16, weight: .bold)) // Slightly larger title
                        .foregroundColor(AppColor.textPrimary)
                    
                    if let location = event.locationName {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(AppColor.primary)
                                .font(.caption)
                            Text(location)
                                .font(.caption)
                                .foregroundColor(AppColor.textSecondary)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundColor(AppColor.primary)
                            .font(.caption)
                        Text(event.dayLabel + " • " + event.timeLabel)
                            .font(.caption)
                            .foregroundColor(AppColor.textSecondary)
                    }
                    
                    NavigationLink(destination: EventDetailScreen(event: event)) {
                        HStack {
                            Text("Detayları Gör")
                                .font(.caption.bold())
                                .foregroundColor(AppColor.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color.white)
        .onAppear {
            checkStatus()
            fetchCreator()
        }
    }
    
    private var fallbackCover: some View {
        Rectangle()
            .fill(Color(hex: event.coverColorHex ?? "5856D6"))
            .aspectRatio(4/3, contentMode: .fit)
            .overlay(
                Image(systemName: event.category.icon)
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.5))
            )
    }
    
    private func fetchCreator() {
        if creator == nil {
            Task {
                if let user = try? await userStore.repo.fetchUser(id: event.createdBy) {
                    await MainActor.run { self.creator = user }
                }
            }
        }
    }
    
    private func toggleLike() {
        isLiked.toggle()
        Task {
            if isLiked {
                try? await interactions.likeEvent(eventId: event.id, uid: userStore.currentUser.id)
            } else {
                try? await interactions.unlikeEvent(eventId: event.id, uid: userStore.currentUser.id)
            }
        }
    }
    
    private func toggleSave() {
        isSaved.toggle()
        Task {
            if isSaved {
                try? await userStore.repo.saveEvent(eventId: event.id, uid: userStore.currentUser.id)
            } else {
                try? await userStore.repo.unsaveEvent(eventId: event.id, uid: userStore.currentUser.id)
            }
        }
    }
    
    private func checkStatus() {
        Task {
            isSaved = (try? await userStore.repo.fetchSavedEventIds(uid: userStore.currentUser.id).contains(event.id)) ?? false
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

