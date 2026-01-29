//
//  EventMapDetailSheet.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

struct EventMapDetailSheet: View {
    let event: Event
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            RoundedRectangle(cornerRadius: 3)
                .fill(AppColor.textSecondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(event.title)
                                .font(AppFont.title2)
                                .foregroundColor(.semtioDarkText)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.semtioPrimary)
                                Text(event.locationName ?? "Konum belirtilmedi")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gray.opacity(0.5))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    Divider()
                    
                    // Time Info
                    VStack(alignment: .leading, spacing: 12) {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Başlangıç")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(event.startDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(AppFont.calloutBold)
                                    .foregroundColor(.semtioDarkText)
                            }
                        } icon: {
                            Image(systemName: "calendar")
                                .foregroundColor(.semtioPrimary)
                        }
                        
                        if let endDate = event.endDate {
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Bitiş")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Text(endDate.formatted(date: .abbreviated, time: .shortened))
                                        .font(AppFont.calloutBold)
                                        .foregroundColor(.semtioDarkText)
                                }
                            } icon: {
                                Image(systemName: "clock")
                                    .foregroundColor(.semtioPrimary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Description
                    if let description = event.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Açıklama")
                                .font(.headline)
                                .foregroundColor(.semtioDarkText)
                            
                            Text(description)
                                .font(.body)
                                .foregroundColor(.gray)
                                .lineLimit(5)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Category Badge
                    HStack {
                        Text(event.category.localizedName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.semtioPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.semtioPrimary.opacity(0.1))
                            .cornerRadius(12)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                            Text("\(event.participantCount)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    // Join Button
                    NavigationLink(destination: EventDetailScreen(event: event)) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .font(.title3)
                            Text("Gruba Katıl")
                                .font(AppFont.headline)
                        }
                        .foregroundColor(AppColor.onPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.semtioPrimary)
                        .cornerRadius(28)
                        .shadow(color: Color.semtioPrimary.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color.semtioBackground)
    }
}
