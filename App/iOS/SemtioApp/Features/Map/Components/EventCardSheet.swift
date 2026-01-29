//
//  EventCardSheet.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Compact bottom sheet card for event details from map marker tap.
//

import SwiftUI
import CoreLocation

struct EventCardSheet: View {
    let event: Event
    @Binding var isExpanded: Bool
    let onDismiss: () -> Void
    let onJoin: () -> Void
    
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var userStore: UserStore
    @State private var isJoining = false
    @State private var joinStatus: JoinRequestStatus?
    @State private var isCheckingStatus = false
    
    private var isOwner: Bool {
        event.createdBy == userStore.currentUser.id
    }
    
    private func checkJoinStatus() {
        guard event.visibility != .public && !isOwner else { return }
        isCheckingStatus = true
        Task {
            joinStatus = await eventStore.getJoinRequestStatus(eventId: event.id, userId: userStore.currentUser.id)
            isCheckingStatus = false
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 10)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // 1. Full Width Cover Image
                    ZStack(alignment: .topTrailing) {
                        if let coverImageURL = event.coverImageURL, let url = URL(string: coverImageURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .clipped()
                            } placeholder: {
                                fallbackCover
                            }
                        } else {
                            fallbackCover
                        }
                        
                        // Close Button Overlay
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        }
                        .padding(16)
                    }
                    
                    // 2. Info Content
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // Header: Title & Category
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(event.category.localizedName.uppercased())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColor.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppColor.primary.opacity(0.1))
                                    .cornerRadius(6)
                                
                                Spacer()
                                
                                // Participant Count Badge
                                Label("\(event.participantCount)" + (event.capacityLimit != nil ? "/\(event.capacityLimit!)" : ""), systemImage: "person.2.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(event.title)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(AppColor.textPrimary)
                                .lineLimit(2)
                        }
                        
                        // Details Row (Time & Location)
                        HStack(spacing: 20) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .foregroundColor(AppColor.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.dayLabel)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(event.timeLabel)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(AppColor.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.locationName ?? "Konum")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    Text(event.district ?? "İstanbul")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Description
                        if let desc = event.description, !desc.isEmpty {
                            Text("Hakkında")
                                .font(.headline)
                                .padding(.top, 4)
                            
                            Text(desc)
                                .font(.body)
                                .foregroundColor(AppColor.textSecondary)
                                .lineLimit(isExpanded ? nil : 3)
                                .onTapGesture {
                                    withAnimation { isExpanded.toggle() }
                                }
                        }
                        
                        Spacer(minLength: 20)
                        
                        // ACTION BUTTON
                        joinButton
                            .padding(.bottom, 20)
                    }
                    .padding(20)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedCornersShape(corners: [.topLeft, .topRight], radius: 24))
        .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
    }
    
    private var fallbackCover: some View {
        Rectangle()
            .fill(Color(hex: event.coverColorHex ?? "5856D6"))
            .frame(height: 200)
            .overlay(
                Image(systemName: event.category.icon)
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.5))
            )
    }
    
    @ViewBuilder
    private var joinButton: some View {
        if isOwner {
            NavigationLink(destination: EventDetailScreen(event: event)) {
                Label("Etkinliği Yönet", systemImage: "gearshape.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppColor.primaryFallback)
                    .cornerRadius(16)
            }
        } else if event.isFull {
            Label("Etkinlik Dolu", systemImage: "xmark.circle")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.gray)
                .cornerRadius(16)
        } else {
            // Visibility Check
            if event.visibility == .public {
                // Direct Join
                Button(action: {
                    isJoining = true
                    onJoin() // This calls parent's direct join logic
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { isJoining = false }
                }) {
                    HStack {
                         if isJoining {
                             ProgressView().tint(.white)
                         } else {
                             Text("Etkinliğe Katıl")
                                 .fontWeight(.bold)
                         }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(colors: [AppColor.primary, Color.purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(16)
                    .shadow(color: AppColor.primary.opacity(0.4), radius: 8, y: 4)
                }
                .disabled(isJoining)
            } else {
                // Request Access Logic
                Button(action: {
                    handleJoinRequest()
                }) {
                    HStack {
                         if isJoining || isCheckingStatus {
                             ProgressView().tint(.white)
                         } else if joinStatus == .pending {
                             Label("İstek Gönderildi", systemImage: "clock.fill")
                                 .fontWeight(.bold)
                         } else if joinStatus == .approved {
                             Label("Kabul Edildi", systemImage: "checkmark.circle.fill")
                                 .fontWeight(.bold)
                         } else if joinStatus == .rejected {
                             Label("Reddedildi", systemImage: "xmark.circle.fill")
                                 .fontWeight(.bold)
                         } else {
                             Text("İstek Gönder")
                                 .fontWeight(.bold)
                         }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        joinStatus == .pending ? Color.orange :
                        joinStatus == .approved ? Color.green :
                        joinStatus == .rejected ? Color.red :
                        AppColor.primary
                    )
                    .cornerRadius(16)
                    .shadow(radius: 4)
                }
                .disabled(isJoining || isCheckingStatus || joinStatus != nil)
                .onAppear {
                    checkJoinStatus()
                }
            }
        }
    }
    
    private func handleJoinRequest() {
        guard let avatar = userStore.currentUser.avatarURL else { return } // Simplify
        isJoining = true
        Task {
            let success = await eventStore.submitJoinRequest(
                eventId: event.id,
                userId: userStore.currentUser.id,
                userName: userStore.currentUser.username ?? "User",
                userAvatarURL: userStore.currentUser.avatarURL
            )
            isJoining = false
            if success {
                joinStatus = .pending
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EventCardSheet(
        event: Event(
            id: "1",
            title: "Kadıköy Açık Hava Konseri",
            description: "Harika bir gece geçireceğiz! Müzik, dans ve eğlence dolu bir akşam için herkesi bekliyoruz.",
            startDate: Date(),
            endDate: nil,
            locationName: "Kadıköy Sahil",
            semtName: nil,
            hostUserId: "user1",
            participantCount: 15,
            coverColorHex: "5856D6",
            category: .music,
            lat: 41.0,
            lon: 29.0,
            capacityLimit: 20,
            tags: ["music", "outdoor"],
            isFeatured: false,
            createdBy: "user2",
            createdAt: Date(),
            district: "Kadıköy",
            visibility: .public
        ),
        isExpanded: .constant(false),
        onDismiss: {},
        onJoin: {}
    )
    .environmentObject(UserStore(repo: MockUserRepository()))
}
