//
//  EventMarkerView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Custom marker view for map events with visual states.
//

import SwiftUI

struct EventMarkerView: View {
    let event: Event
    let isSelected: Bool
    let isOwner: Bool
    
    /// Marker visual state based on event status
    private var markerState: MarkerState {
        if event.isFull {
            return .full
        } else if event.capacityProgress > 0.8 {
            return .almostFull
        } else if isOwner {
            return .owner
        } else {
            return .active
        }
    }
    
    private enum MarkerState {
        case active, almostFull, full, owner
        
        var ringColor: Color {
            switch self {
            case .active: return .purple
            case .almostFull: return .orange
            case .full: return .red
            case .owner: return .yellow
            }
        }
        
        var fillGradient: [Color] {
            switch self {
            case .active: return [.purple, .purple.opacity(0.7)]
            case .almostFull: return [.orange, .orange.opacity(0.7)]
            case .full: return [.red.opacity(0.6), .gray]
            case .owner: return [.purple, .yellow.opacity(0.8)]
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(markerState.ringColor, lineWidth: isSelected ? 3 : 2)
                .frame(width: 44, height: 44)
            
            // Fill gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: markerState.fillGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
            
            // Category icon or X for full
            if markerState == .full {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColor.onPrimary)
            } else {
                Image(systemName: event.category.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColor.onPrimary)
            }
            
            // Owner badge (golden star)
            if isOwner && markerState != .full {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                            .background(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 14, height: 14)
                            )
                    }
                    Spacer()
                }
                .frame(width: 44, height: 44)
            }
        }
        .shadow(color: markerState.ringColor.opacity(0.4), radius: isSelected ? 8 : 4, x: 0, y: 2)
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        // Subtle pulse for active markers
        .modifier(PulseAnimationModifier(isActive: markerState == .active && !isSelected))
    }
}

// MARK: - Pulse Animation

private struct PulseAnimationModifier: ViewModifier {
    let isActive: Bool
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .stroke(Color.purple.opacity(isPulsing ? 0 : 0.3), lineWidth: 2)
                    .frame(width: 50, height: 50)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
            )
            .onAppear {
                guard isActive else { return }
                withAnimation(
                    .easeOut(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        HStack(spacing: 20) {
            EventMarkerView(
                event: Event.mockActive,
                isSelected: false,
                isOwner: false
            )
            
            EventMarkerView(
                event: Event.mockAlmostFull,
                isSelected: false,
                isOwner: false
            )
            
            EventMarkerView(
                event: Event.mockFull,
                isSelected: false,
                isOwner: false
            )
            
            EventMarkerView(
                event: Event.mockActive,
                isSelected: false,
                isOwner: true
            )
        }
        
        EventMarkerView(
            event: Event.mockActive,
            isSelected: true,
            isOwner: false
        )
    }
    .padding()
    .background(AppColor.textSecondary.opacity(0.2))
}

// Mock events have been moved to Core/Models/Event+Mock.swift
