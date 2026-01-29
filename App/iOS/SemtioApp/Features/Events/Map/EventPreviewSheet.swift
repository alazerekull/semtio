//
//  EventPreviewSheet.swift
//  SemtioApp
//
//  Created for MapKit Integration
//

import SwiftUI
import FirebaseFirestore

struct EventPreviewSheet: View {
    let event: FirestoreEvent
    @ObservedObject var viewModel: EventMapViewModel
    let onClose: () -> Void
    
    var isJoined: Bool {
        guard let uid = viewModel.currentUser?.id else { return false }
        return event.attendees?.contains(uid) ?? false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
            .padding(.top)
            
            if let imageUrl = event.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(12)
                    } else if phase.error != nil {
                        Color.gray.opacity(0.3)
                            .frame(height: 200)
                            .cornerRadius(12)
                    } else {
                        ProgressView()
                            .frame(height: 200)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let date = event.date?.dateValue() {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let city = event.city {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                        Text(city)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            

            Spacer()
            
            // Action Button
            if viewModel.currentUser != nil {
                if isJoined {
                    HStack {
                        Spacer()
                        Label("Katıldın", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.green)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        Spacer()
                    }
                } else {
                    Button {
                        Task {
                            await viewModel.joinEvent(event: event)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isJoining {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(event.visibilityEnum == .requestApproval ? "İstek Gönder" : "Katıl")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(event.visibilityEnum == .requestApproval ? Color.orange : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isJoining)
                }
            }
            
            if let error = viewModel.joinError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            if let msg = viewModel.joinSuccessMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal)
            }
        }
        .padding()
        .presentationDetents([.fraction(0.45), .medium])
    }
}
