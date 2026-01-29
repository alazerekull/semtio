//
//  AnnouncementBanner.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct AnnouncementBanner: View {
    let title: String
    let message: String
    let icon: String
    
    init(title: String = "Duyuru", message: String = "Yeni özellikler yakında geliyor! 🎉", icon: String = "megaphone.fill") {
        self.title = title
        self.message = message
        self.icon = icon
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.semtioPrimary)
                .frame(width: 40, height: 40)
                .background(Color.semtioPrimary.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.semtioDarkText)
                
                Text(message)
                    .font(AppFont.footnote)
                    .foregroundColor(.semtioGrayText)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.gray.opacity(0.4))
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.semtioPrimary.opacity(0.08), Color.purple.opacity(0.05)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.semtioPrimary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}
