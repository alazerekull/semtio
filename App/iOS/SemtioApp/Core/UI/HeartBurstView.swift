//
//  HeartBurstView.swift
//  SemtioApp
//
//  Instagram-style heart burst animation.
//

import SwiftUI

struct HeartBurstView: View {
    @Binding var isPresented: Bool
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            if isPresented {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
        }
        .onChange(of: isPresented) { _, newValue in
            if newValue {
                animate()
            }
        }
    }
    
    private func animate() {
        // Reset state
        scale = 0.5
        opacity = 0.0
        
        // Pop in
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            scale = 1.2
            opacity = 1.0
        }
        
        // Check for quick dismissal usage? No, we want a strict timeline.
        // Fade out after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.2)) {
                scale = 1.4
                opacity = 0.0
            }
        }
        
        // Reset visible state binding
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isPresented = false
            scale = 0.5 // Reset for next time
        }
    }
}
