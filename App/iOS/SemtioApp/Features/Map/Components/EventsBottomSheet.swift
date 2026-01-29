//
//  EventsBottomSheet.swift
//  SemtioApp
//
//  Created for Semtio Map Refactor.
//

import SwiftUI

struct EventsBottomSheet: View {
    let districtName: String?
    let isLoading: Bool
    let errorText: String?
    let events: [Event]
    let onSelect: (Event) -> Void
    
    @State private var selectedFilter: String = "Bugün"
    let filters = ["Bugün", "Bu Hafta", "Yakın", "Ücretsiz"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            Capsule()
                .fill(AppColor.textSecondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 15)
            
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(districtName != nil ? "\(districtName!) Etkinlikleri" : "Etkinlikler")
                    .font(.headline)
                    .foregroundColor(AppColor.textPrimary)
                
                // Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters, id: \.self) { filter in
                            FilterChip(title: filter, isSelected: selectedFilter == filter) {
                                selectedFilter = filter
                                // TODO: Trigger actual filtering callback
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            Divider()
            
            // Content
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: 200)
            } else if let error = errorText {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else if events.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Bu bölgede etkinlik bulunamadı.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                List(events) { event in
                    BottomSheetEventRow(event: event)
                        .onTapGesture {
                            onSelect(event)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .listStyle(.plain)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.semtioPrimary : AppColor.textSecondary.opacity(0.1))
                .cornerRadius(16)
        }
    }
}

struct BottomSheetEventRow: View {
    let event: Event
    
    var body: some View {
        HStack(spacing: 12) {
            // Image Placeholder
            Rectangle()
                .fill(AppColor.textSecondary.opacity(0.2))
                .frame(width: 60, height: 60)
                .cornerRadius(12) // Rounded
                .overlay(
                    Image(systemName: event.category.icon)
                        .foregroundColor(.gray)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(2)
                
                HStack(spacing: 4) {
                    Text(event.timeLabel)
                        .font(.caption)
                    Text("•")
                        .font(.caption)
                    Text(event.dayLabel)
                        .font(.caption)
                }
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Status Badge
            Text(event.visibility.localizedName)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(event.visibility == .public ? .green : .orange)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    (event.visibility == .public ? Color.green : Color.orange).opacity(0.1)
                )
                .cornerRadius(8)
            
            // CTA Button (Mini)
            Button(action: {
                // Action handled by parent via selection or separate callback
            }) {
                Image(systemName: event.visibility == .public ? "plus.circle.fill" : "envelope.circle.fill")
                    .font(.title2)
                    .foregroundColor(.semtioPrimary)
            }
        }
        .padding(8)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
