//
//  AnnouncementDetailScreen.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct AnnouncementDetailScreen: View {
    let announcement: Announcement
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(announcement.title)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.semtioDarkText)
                    
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Divider()
                
                // Content
                Text(announcement.body)
                    .font(.body)
                    .foregroundColor(.semtioDarkText)
                    .lineSpacing(6)
                
                // Action Button (if URL exists)
                if let url = announcement.actionURL {
                    Link(destination: url) {
                        HStack {
                            Text("Detaylara Git")
                                .font(AppFont.calloutBold)
                            Image(systemName: "arrow.right")
                        }
                        .foregroundColor(AppColor.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.semtioPrimary)
                        .cornerRadius(12)
                    }
                    .padding(.top, 16)
                }
                
                Spacer()
            }
            .padding()
        }
        .background(Color.semtioBackground)
        .navigationTitle("Duyuru")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateStyle = .long
        return formatter.string(from: announcement.createdAt)
    }
}
