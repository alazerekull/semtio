//
//  WalkthroughTooltipView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct WalkthroughTooltipView: View {
    let step: WalkthroughStep
    let currentIndex: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Icon + Title
            HStack(spacing: Spacing.sm) {
                Image(systemName: step.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color.semtioPrimary)

                Text(step.title)
                    .font(AppFont.headline)
                    .foregroundColor(AppColor.textPrimary)
            }

            // Description
            Text(step.description)
                .font(AppFont.body)
                .foregroundColor(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Swipe hint for steps 3 and 4
            if step.id == 3 || step.id == 4 {
                SwipeHintView(direction: step.id == 3 ? .leading : .trailing)
                    .frame(height: 30)
                    .frame(maxWidth: .infinity)
            }

            // Progress dots + navigation buttons
            HStack {
                // Progress dots
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i == currentIndex ? Color.semtioPrimary : AppColor.border)
                            .frame(width: 8, height: 8)
                            .scaleEffect(i == currentIndex ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentIndex)
                    }
                }

                Spacer()

                // Navigation buttons
                HStack(spacing: Spacing.sm) {
                    if currentIndex > 0 {
                        Button(action: onPrevious) {
                            Text("Geri")
                                .font(AppFont.captionBold)
                                .foregroundColor(AppColor.textSecondary)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                        }
                    }

                    Button(action: onNext) {
                        Text(currentIndex == totalSteps - 1 ? "Tamam" : "İleri")
                            .font(AppFont.captionBold)
                            .foregroundColor(AppColor.onPrimary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.semtioPrimary)
                            .cornerRadius(Radius.pill)
                    }
                }
            }

            // Skip button (not on last step)
            if currentIndex < totalSteps - 1 && currentIndex > 0 {
                Button(action: onSkip) {
                    Text("Geç")
                        .font(AppFont.caption)
                        .foregroundColor(AppColor.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(Spacing.lg)
        .background(AppColor.surface)
        .cornerRadius(Radius.lg)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .padding(.horizontal, Spacing.lg)
    }
}
