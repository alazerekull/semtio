//
//  SwipeHintView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct SwipeHintView: View {
    let direction: SwipeDirection

    @State private var animating = false

    enum SwipeDirection {
        case leading  // Swipe right
        case trailing // Swipe left
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if direction == .leading {
                // Right swipe: hand pointing right with arrow
                Image(systemName: "hand.point.right.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color.semtioPrimary)

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.semtioPrimary.opacity(0.7))

                Text("Gizle")
                    .font(AppFont.captionBold)
                    .foregroundColor(Color.indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.15))
                    .cornerRadius(Radius.sm)
            } else {
                // Left swipe: archive and delete labels with hand
                Text("Arşivle")
                    .font(AppFont.captionBold)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(Radius.sm)

                Text("Sil")
                    .font(AppFont.captionBold)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(Radius.sm)

                Image(systemName: "arrow.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.semtioPrimary.opacity(0.7))

                Image(systemName: "hand.point.left.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color.semtioPrimary)
            }
        }
        .offset(x: animating ? (direction == .leading ? 10 : -10) : 0)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true)
            ) {
                animating = true
            }
        }
        .onDisappear {
            animating = false
        }
    }
}
