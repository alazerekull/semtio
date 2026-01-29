//
//  MessageBubble.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import MapKit

struct MessageBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser {
                 Spacer()
            }
            
            if !isCurrentUser {
                // Avatar placeholder or actual avatar if available
                Circle()
                    .fill(AppColor.textSecondary.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(Text(message.senderName.prefix(1).uppercased()).font(.caption).bold())
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser && !message.senderName.isEmpty {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.leading, 4)
                }
                
                // STRICT TYPE CHECK: If text is "post", show card regardless of text content
                if message.type == .post {
                    PostCardBubble(
                        postId: message.normalizedPostId,
                        message: message,
                        isCurrentUser: isCurrentUser
                    )
                } else if message.type == .event {
                    EventCardBubble(
                        message: message,
                        isCurrentUser: isCurrentUser
                    )
                } else if message.type == .image, let urlString = message.attachmentURL, let url = URL(string: urlString) {
                    // Image Message
                    AsyncImage(url: url) { param in
                        if let image = param.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else if param.error != nil {
                            AppColor.textSecondary
                                .overlay(Image(systemName: "exclamationmark.triangle"))
                        } else {
                            ProgressView()
                                .frame(width: 40, height: 40)
                                .background(AppColor.textSecondary.opacity(0.1))
                        }
                    }
                    .frame(width: 200, height: 260) // Simple constraints logic
                    .background(AppColor.textSecondary.opacity(0.1))
                    .cornerRadius(16)
                    .clipShape(RoundedCornersShape(corners: [
                        .topLeft, .topRight,
                        isCurrentUser ? .bottomLeft : .bottomRight
                    ], radius: 16))
                } else if let sharedPostId = message.sharedPostId, !sharedPostId.isEmpty {
                    // Fallback for old messages that might be .text type but have sharedPostId
                    PostCardBubble(
                        postId: sharedPostId,
                        message: message,
                        isCurrentUser: isCurrentUser
                    )
                } else {
                    // Standard Text Message
                    Text(message.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(isCurrentUser ? Color.semtioPrimary : Color(uiColor: .secondarySystemBackground))
                        .foregroundColor(isCurrentUser ? .white : .primary)
                        .cornerRadius(20)
                        .clipShape(RoundedCornersShape(corners: [
                            .topLeft, .topRight,
                            isCurrentUser ? .bottomLeft : .bottomRight
                        ], radius: 20))
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                
                // Time and Read Receipt Status
                HStack(spacing: 4) {
                    Text(message.timeLabel)
                         .font(.caption2)
                         .foregroundColor(.gray)
                    
                    // WhatsApp-style checkmarks (only for sender's messages)
                    if isCurrentUser {
                        if message.isRead {
                            // Double blue check = Read
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.blue)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.blue)
                                .offset(x: -6)
                        } else {
                            // Single gray check = Sent (not read)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(isCurrentUser ? .trailing : .leading, 4)
            }
            
            if !isCurrentUser {
                 Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
    }
}


struct EventCardBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    @EnvironmentObject var appState: AppState // For navigation
    
    // Live Event State (Backend Connection)
    @State private var fetchedEvent: Event? = nil
    @State private var debugError: String? = nil
    
    // Priority: Live Data -> Preview Snapshot -> Default
    var displayTitle: String { fetchedEvent?.title ?? message.eventPreview?.title ?? "Etkinlik" }
    var displayLocation: String? { fetchedEvent?.locationName ?? message.eventPreview?.locationName }
    var displayCoverURL: String? { fetchedEvent?.coverImageURL ?? message.eventPreview?.coverImageURL }
    var displayLat: Double? { fetchedEvent?.lat ?? message.eventPreview?.lat }
    var displayLon: Double? { fetchedEvent?.lon ?? message.eventPreview?.lon }
    var displayDate: String {
        if let event = fetchedEvent { return event.dayLabel }
        return message.eventPreview?.dateLabel ?? ""
    }
    var displayCategory: String? { fetchedEvent?.category.rawValue ?? message.eventPreview?.category }
    var displayCategoryIcon: String { fetchedEvent?.category.icon ?? message.eventPreview?.categoryIcon ?? "calendar" }
    
    var body: some View {
        Button {
            if let eventId = message.sharedEventId {
                appState.handleDeepLink(URL(string: "semtio://event/\(eventId)")!)
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // DEBUG AREA
                if let err = debugError {
                    Text(err)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .padding(4)
                }
                
                // 1. Media Area (Image or Gradient Fallback)
                ZStack {
                    if let urlString = displayCoverURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                    } else {
                        // Fallback: Gradient + Icon
                        gradientForCategory(displayCategory)
                        
                        Image(systemName: displayCategoryIcon)
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(radius: 4)
                    }
                }
                .frame(height: 120)
                .clipped()
                .overlay(
                    // Top Left Badge: Mini Map OR Date
                    Group {
                        if let lat = displayLat, let lon = displayLon {
                            // Mini Map Badge (Backend Connected)
                            Map(position: .constant(.region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                            )))) {
                                Marker("", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                            }
                            .frame(width: 50, height: 50)
                            .cornerRadius(12)
                            .disabled(true) // Static interaction
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 4)
                        } else {
                            // Date Badge Fallback
                            HStack {
                                VStack(spacing: 0) {
                                    Text("BİLGİ")
                                        .font(.system(size: 8, weight: .bold))
                                        .textCase(.uppercase)
                                    Image(systemName: "calendar")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(.primary)
                                .padding(6)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                                .shadow(radius: 2)
                            }
                        }
                    }
                    .padding(8),
                    alignment: .topLeading
                )
                
                // 2. Info Area
                VStack(alignment: .leading, spacing: 6) {
                    Text(displayTitle)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(2)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                    
                    if let location = displayLocation {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(AppColor.primary)
                            Text(location)
                                .lineLimit(1)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    if !displayDate.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundColor(AppColor.primary)
                            Text(displayDate)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)    
                    }
                    
                    HStack {
                        Text("Detayları Gör")
                            .font(.caption.bold())
                            .foregroundColor(AppColor.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 6)
                }
                .padding(12)
                .background(Color(.systemBackground))
            }
            .frame(width: 240)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
            // Border
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            // BACKEND CONNECTION: Fetch live event data immediately
            if let eventId = message.sharedEventId {
                do {
                    self.fetchedEvent = try await appState.events.repo.fetchEvent(eventId: eventId)
                    self.debugError = nil
                } catch {
                    print("⚠️ Failed to fetch live event for bubble: \(error)")
                    self.debugError = "Err: \(error.localizedDescription)"
                }
            } else {
                self.debugError = "No Event ID"
            }
        }
    }
    
    // Helpers
    
    private func gradientForCategory(_ categoryRaw: String?) -> LinearGradient {
        let category = EventCategory(rawValue: categoryRaw ?? "") ?? .other
        
        switch category {
        case .party:
            return LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sport:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .music:
            return LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .food:
            return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .meetup:
            return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .other:
            return LinearGradient(colors: [.indigo, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

