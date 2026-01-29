//
//  SplashView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct SplashView: View {
    @State private var isAnimating = false
    let text = "Semtio"
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea() // White background as requested
            
            VStack { // Removed spacing
                Spacer()
                
                // Logo Icon
                Image("SplashLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300) // Much larger size as requested
                    .scaleEffect(isAnimating ? 1.0 : 0.3) // Drastic scale animation
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: isAnimating)
                
                Spacer()
                
                // Keep spinner but minimal
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .semtioPrimary))
                    .scaleEffect(1.2)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}
