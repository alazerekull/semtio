//
//  JoinRequestsSheet.swift
//  SemtioApp
//
//  Created by Semtio Assitant.
//

import SwiftUI

struct JoinRequestsSheet: View {
    let event: Event
    let eventRepo: EventRepository
    let userRepo: UserRepository
    let onUpdate: () async -> Void
    
    @Environment(\.dismiss) var dismiss
    
    @State private var requests: [JoinRequest] = []
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("İstekler Yükleniyor...")
                } else if let error = error {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error.localizedDescription)
                            .padding()
                        Button("Tekrar Dene") {
                            loadRequests()
                        }
                    }
                } else if requests.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 50))
                            .foregroundColor(AppColor.textSecondary)
                        Text("Bekleyen istek yok")
                            .font(.headline)
                            .foregroundColor(AppColor.textSecondary)
                    }
                } else {
                    List {
                        ForEach(requests) { request in
                            RequestRow(request: request, onAction: { approve in
                                handleAction(request: request, approve: approve)
                            })
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Katılım İstekleri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
            .task {
                loadRequests()
            }
        }
    }
    
    private func loadRequests() {
        isLoading = true
        error = nil
        Task {
            do {
                requests = try await eventRepo.fetchPendingJoinRequests(eventId: event.id)
                isLoading = false
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
    
    private func handleAction(request: JoinRequest, approve: Bool) {
        Task {
            do {
                try await eventRepo.respondToJoinRequest(eventId: event.id, requestId: request.id, approve: approve, note: nil)
                // Remove from list
                withAnimation {
                    requests.removeAll { $0.id == request.id }
                }
                // Notify parent to refresh counts
                await onUpdate()
            } catch {
                print("Error responding to request: \(error)")
            }
        }
    }
}

struct RequestRow: View {
    let request: JoinRequest
    let onAction: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AsyncImage(url: URL(string: request.userAvatarURL ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(request.userName)
                    .font(.headline)
                
                Text(request.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(AppColor.textSecondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Reject Button
                Button {
                    onAction(false) // Reject
                } label: {
                    Image(systemName: "xmark")
                        .fontWeight(.bold)
                        .padding(10)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                // Approve Button
                Button {
                    onAction(true) // Approve
                } label: {
                    Image(systemName: "checkmark")
                        .fontWeight(.bold)
                        .padding(10)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }
}
