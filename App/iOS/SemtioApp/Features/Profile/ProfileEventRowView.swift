//
//  ProfileEventRowView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Enhanced event row with staggered animations, refined layout, and visual depth

import SwiftUI

struct ProfileEventRowView: View {
    let event: Event
    var accentColor: Color = AppColor.primaryFallback
    var index: Int = 0

    @State private var isAppeared = false

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: event.startDate)
    }

    private var isPast: Bool {
        event.startDate < Date()
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon with accent color background
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.2), accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: event.category.icon)
                    .font(AppFont.title3)
                    .foregroundColor(accentColor)
            }
            .frame(width: 52, height: 52)

            // Content
            VStack(alignment: .leading, spacing: 5) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(isPast ? AppColor.textSecondary : AppColor.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let district = event.district ?? event.semtName {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .font(.system(size: 9, weight: .medium))
                            Text(district)
                                .font(AppFont.caption)
                        }
                        .foregroundColor(accentColor.opacity(0.8))
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9, weight: .medium))
                        Text(formattedDate)
                            .font(AppFont.caption)
                    }
                    .foregroundColor(AppColor.textSecondary)
                }
            }

            Spacer()

            // Live indicator or chevron
            if event.isActive {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColor.success)
                        .frame(width: 6, height: 6)
                    Text("Canlı")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(AppColor.success)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(AppColor.success.opacity(0.12))
                )
            } else {
                Image(systemName: "chevron.right")
                    .font(AppFont.captionBold)
                    .foregroundColor(accentColor.opacity(0.4))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 11)
        .background(AppColor.surface)
        .contentShape(Rectangle())
        .opacity(isAppeared ? 1.0 : 0)
        .offset(x: isAppeared ? 0 : 20)
        .onAppear {
            let delay = Double(index) * 0.06
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay)) {
                isAppeared = true
            }
        }
    }
}
