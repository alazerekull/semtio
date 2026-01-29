//
//  ProfileEventsModuleView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Modern events module with refined cards, smooth animations, and visual hierarchy

import SwiftUI

enum ProfileEventTab: String, CaseIterable, Identifiable {
    case created = "Oluşturduklarım"
    case upcoming = "Yaklaşan"
    case past = "Geçmiş Katılımlar"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .created: return "plus.circle.fill"
        case .upcoming: return "calendar.badge.clock"
        case .past: return "clock.arrow.circlepath"
        }
    }

    var accentColor: Color {
        switch self {
        case .created: return Color.purple
        case .upcoming: return Color.green
        case .past: return Color.orange
        }
    }
}

struct ProfileEventsModuleView: View {
    let createdEvents: [Event]
    let joinedEvents: [Event]
    let isLoading: Bool
    let onEventTap: (Event) -> Void
    var onCreateTapped: (() -> Void)? = nil

    @State private var selectedTab: ProfileEventTab = .created
    @State private var isAppeared = false
    @State private var hasSetInitialTab = false

    private var upcomingEvents: [Event] {
        let now = Date()
        return joinedEvents.filter { $0.startDate > now }.sorted { $0.startDate < $1.startDate }
    }

    private var pastEvents: [Event] {
        // Combined past events (Joined + Created)
        let pastJoined = joinedEvents.filter { $0.isPast }
        let pastCreated = createdEvents.filter { $0.isPast }
        
        // Combine and deduplicate by ID
        let allPast = (pastJoined + pastCreated)
        let uniquePast = Array(Dictionary(grouping: allPast, by: { $0.id }).values.compactMap { $0.first })
        
        return uniquePast.sorted { $0.startDate > $1.startDate }
    }

    private var currentEvents: [Event] {
        switch selectedTab {
        case .upcoming:
            return upcomingEvents
        case .past:
            return pastEvents
        case .created:
            // Only show active/future created events
            return createdEvents
                .filter { !$0.isPast }
                .sorted { $0.createdAt > $1.createdAt }
        }
    }

    private var emptyMessage: String {
        switch selectedTab {
        case .upcoming:
            return "Yaklaşan etkinliğin yok."
        case .past:
            return "Henüz etkinliklere katılmadın."
        case .created:
            return "Henüz etkinlik oluşturmadın."
        }
    }

    private var emptyIcon: String {
        switch selectedTab {
        case .upcoming:
            return "calendar.badge.plus"
        case .past:
            return "clock"
        case .created:
            return "plus.square.dashed"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Modern Header with clean design
            HStack(alignment: .center) {
                Text("Etkinliklerim")
                    .font(AppFont.title3)
                    .foregroundColor(AppColor.textPrimary)
                
                Spacer()

                // Create Button with enhanced styling
                if let onCreate = onCreateTapped {
                    Button(action: onCreate) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(AppFont.callout)
                            Text("Yeni")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(AppColor.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(AppColor.primary.opacity(0.12))
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.md)


            // Clean Tab Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ProfileEventTab.allCases) { tab in
                        Button {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedTab = tab
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11, weight: .medium))
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .medium, design: .rounded))
                            }
                            .foregroundColor(selectedTab == tab ? .white : AppColor.textSecondary)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(selectedTab == tab ? tab.accentColor : AppColor.surface)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedTab == tab ? Color.clear : AppColor.border.opacity(0.3), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .padding(.bottom, Spacing.md)

            // Subtle Count Indicator
            HStack {
                Text("\(currentEvents.count) etkinlik")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppColor.textSecondary)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.sm)

            // Content
            if isLoading {
                VStack(spacing: Spacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        ShimmerView()
                            .frame(height: 64)
                            .cornerRadius(Radius.md)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.md)
            } else if currentEvents.isEmpty {
                // Empty State
                Button(action: {
                    onCreateTapped?()
                }) {
                    VStack(spacing: Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(selectedTab.accentColor.opacity(0.1))
                                .frame(width: 64, height: 64)
                            Image(systemName: selectedTab == .created ? "plus" : emptyIcon)
                                .font(.system(size: 26, weight: .medium))
                                .foregroundColor(selectedTab.accentColor.opacity(0.6))
                        }
                        Text(emptyMessage)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(AppColor.textSecondary)

                        if selectedTab == .created {
                            Text("Etkinlik Oluştur")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppColor.onPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(AppColor.primary)
                                )
                        }
                    }
                    .frame(height: selectedTab == .created ? 180 : 140)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(currentEvents.prefix(5).enumerated()), id: \.element.id) { index, event in
                        Button {
                            onEventTap(event)
                        } label: {
                            ProfileEventRowView(event: event, accentColor: selectedTab.accentColor, index: index)
                        }
                        .buttonStyle(PlainButtonStyle())

                        if event.id != currentEvents.prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 76)
                                .opacity(0.6)
                        }
                    }
                }
                .padding(.top, Spacing.sm)
            }
        }
        .padding(.bottom, Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(AppColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(selectedTab.accentColor.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        .scaleEffect(isAppeared ? 1.0 : 0.95)
        .opacity(isAppeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) {
                isAppeared = true
            }
            if !hasSetInitialTab {
                hasSetInitialTab = true
                // If all created events are in the past, default to past tab
                let now = Date()
                let allCreatedArePast = !createdEvents.isEmpty && createdEvents.allSatisfy { $0.startDate <= now }
                if allCreatedArePast {
                    selectedTab = .past
                }
            }
        }
    }
}
