//
//  FilterPillsView.swift
//  SemtioApp
//
//  Enhanced for premium UI/UX.
//

import SwiftUI

struct FilterPillsView<T: Identifiable & RawRepresentable>: View where T.RawValue == String {
    let options: [T]
    @Binding var selected: T
    
    @Namespace private var animation
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(options) { option in
                    FilterPill(
                        title: option.rawValue,
                        isSelected: selected.id == option.id,
                        namespace: animation
                    ) {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selected = option
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Individual Pill

private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : AppColor.textPrimary)
                .padding(.vertical, 10)
                .padding(.horizontal, 18)
                .background(
                    ZStack {
                        if isSelected {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColor.primaryFallback, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .matchedGeometryEffect(id: "pill", in: namespace)
                                .shadow(color: AppColor.primaryFallback.opacity(0.4), radius: 8, x: 0, y: 4)
                        } else {
                            Capsule()
                                .fill(AppColor.surface)
                                .overlay(
                                    Capsule()
                                        .stroke(AppColor.border.opacity(0.5), lineWidth: 1)
                                )
                        }
                    }
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
