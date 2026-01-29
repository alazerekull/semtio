//
//  EventListCard.swift
//  SemtioApp
//
//  Enhanced for premium UI/UX.
//

import SwiftUI

struct EventListCard: View {
    let event: Event
    let mode: EventsViewModel.TabMode
    let onAction: (EventAction) -> Void
    
    @State private var isPressed = false
    
    enum EventAction {
        case tap
        case edit
        case share
        case cancel
        case detail
    }
    
    // MARK: - Computed Properties
    
    private var dateGradient: LinearGradient {
        switch event.category {
        case .music:
            return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sport:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .food:
            return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .party:
            return LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .meetup:
            return LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .other:
            return LinearGradient(colors: [AppColor.primaryFallback, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private var dateGradientShadowColor: Color {
        switch event.category {
        case .music: return .purple
        case .sport: return .orange
        case .food: return .yellow
        case .party: return .blue
        case .meetup: return .green
        case .other: return AppColor.primaryFallback
        }
    }
    
    private var capacityPercentage: Double {
        guard let limit = event.capacityLimit, limit > 0 else { return 0 }
        return Double(event.participantCount) / Double(limit)
    }
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onAction(.tap)
        }) {
            HStack(alignment: .top, spacing: 14) {
                // 1. Enhanced Date Box with Gradient
                dateBox
                
                // 2. Content Area
                VStack(alignment: .leading, spacing: 6) {
                    // Status + Category Row
                    HStack(spacing: 6) {
                        if event.status != .published {
                            statusBadge
                        }
                        
                        categoryBadge
                    }
                    
                    // Title
                    Text(event.title)
                        .font(AppFont.headline)
                        .foregroundColor(AppColor.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Location Row
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(AppFont.caption)
                            .foregroundColor(AppColor.primaryFallback)
                        
                        Text(event.locationName ?? "Konum Belirtilmedi")
                            .font(AppFont.footnote)
                            .foregroundColor(AppColor.textSecondary)
                            .lineLimit(1)
                    }
                    
                    // Participant + Time Info
                    HStack(spacing: 12) {
                        // Participants
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 10))
                            
                            if let limit = event.capacityLimit, limit > 0 {
                                Text("\(event.participantCount)/\(limit)")
                                    .font(AppFont.caption)
                            } else {
                                Text("\(event.participantCount)")
                                    .font(AppFont.caption)
                            }
                        }
                        .foregroundColor(capacityPercentage > 0.8 ? .orange : .blue)
                        
                        // Time remaining indicator
                        if event.isActive {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("Aktif")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 3. Action Indicator
                VStack {
                    Spacer()
                    if mode == .hosted {
                        Menu {
                            Button(action: { onAction(.edit) }) {
                                Label("Düzenle", systemImage: "pencil")
                            }
                            Button(action: { onAction(.share) }) {
                                Label("Paylaş", systemImage: "square.and.arrow.up")
                            }
                            if event.status != .cancelled {
                                Button(role: .destructive, action: { onAction(.cancel) }) {
                                    Label("İptal Et", systemImage: "xmark.circle")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppColor.textSecondary.opacity(0.5))
                        }
                    } else {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(AppFont.title2)
                            .foregroundColor(AppColor.primaryFallback.opacity(0.3))
                    }
                    Spacer()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColor.surface)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColor.border.opacity(0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(CardPressStyle())
    }
    
    // MARK: - Subviews
    
    private var dateBox: some View {
        VStack(spacing: 2) {
            Text(event.dayLabel)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .textCase(.uppercase)
            
            Text(event.timeLabel)
                .font(.system(size: 18, weight: .black))
                .foregroundColor(AppColor.onPrimary)
        }
        .frame(width: 64, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(dateGradient)
                .shadow(color: dateGradientShadowColor.opacity(0.4), radius: 8, x: 0, y: 4)
        )
    }
    
    private var statusBadge: some View {
        Text(event.status.localizedName.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(statusColor(event.status))
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(
                Capsule()
                    .fill(statusColor(event.status).opacity(0.12))
            )
    }
    
    private var categoryBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: event.category.icon)
                .font(.system(size: 9))
            Text(event.category.localizedName)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(AppColor.primaryFallback)
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .background(
            Capsule()
                .fill(AppColor.primaryFallback.opacity(0.1))
        )
    }
    
    private func statusColor(_ status: EventStatus) -> Color {
        switch status {
        case .draft: return .gray
        case .published: return .green
        case .cancelled: return .red
        }
    }
}

// MARK: - Card Press Style

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
