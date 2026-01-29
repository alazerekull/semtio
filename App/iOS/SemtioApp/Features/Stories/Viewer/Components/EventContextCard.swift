//
//  EventContextCard.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct EventContextCard: View {
    let eventId: String
    let name: String
    let date: Date?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                if let date = date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Text("KATIL")
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .cornerRadius(12)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 8)
        .frame(width: 220)
    }
}
