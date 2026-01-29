//
//  JoinRequestsViewModel.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class JoinRequestsViewModel: ObservableObject {
    // MARK: - Published State
    @Published var requests: [JoinRequest] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published var processingIds: Set<String> = []
    
    // Cache for resolved user profiles (id -> User/Profile)
    // Using UserLite or AppUser for display
    @Published var userProfiles: [String: AppUser] = [:]
    
    // Dependencies
    private let eventRepo: EventRepositoryProtocol
    private let userRepo: UserRepositoryProtocol
    private let eventId: String
    
    init(eventId: String, eventRepo: EventRepositoryProtocol, userRepo: UserRepositoryProtocol) {
        self.eventId = eventId
        self.eventRepo = eventRepo
        self.userRepo = userRepo
    }
    
    // MARK: - Actions
    
    func load() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Fetch Requests
            let fetchedRequests = try await eventRepo.fetchPendingJoinRequests(eventId: eventId)
            self.requests = fetchedRequests
            
            // 2. Resolve Users (Fetch fresh profiles)
            await resolveUsers(for: fetchedRequests)
            
        } catch {
            print("❌ Failed to load join requests: \(error)")
            errorMessage = "İstekler yüklenirken bir hata oluştu."
        }
        
        isLoading = false
    }
    
    func approve(_ request: JoinRequest) async {
        await respond(to: request, approve: true)
    }
    
    func reject(_ request: JoinRequest) async {
        await respond(to: request, approve: false)
    }
    
    private func respond(to request: JoinRequest, approve: Bool) async {
        guard !processingIds.contains(request.id) else { return }
        processingIds.insert(request.id)
        
        // Optimistic Update
        let originalRequests = requests
        requests.removeAll { $0.id == request.id }
        
        do {
            try await eventRepo.respondToJoinRequest(
                eventId: eventId,
                requestId: request.id,
                approve: approve,
                note: nil
            )
            // Success - Haptic feedback handled by View or here if we import UIKit
            
        } catch {
            print("❌ Failed to respond to request: \(error)")
            errorMessage = "İşlem başarısız oldu. Lütfen tekrar deneyin."
            
            // Revert optimistic update
            requests = originalRequests
        }
        
        processingIds.remove(request.id)
    }
    
    // MARK: - Helpers
    
    private func resolveUsers(for requests: [JoinRequest]) async {
        let userIds = requests.map { $0.userId }
        guard !userIds.isEmpty else { return }
        
        // Fetch users in parallel (or batch if repo supported it)
        await withTaskGroup(of: (String, AppUser?).self) { group in
            for uid in userIds {
                // Skip if already cached
                if userProfiles[uid] != nil { continue }
                
                group.addTask {
                    do {
                        let user = try await self.userRepo.fetchUser(id: uid)
                        return (uid, user)
                    } catch {
                        return (uid, nil)
                    }
                }
            }
            
            for await (uid, user) in group {
                if let user = user {
                    self.userProfiles[uid] = user
                }
            }
        }
    }
    
    /// Get display name for request (prefer fresh profile, fallback to snapshot)
    func displayName(for request: JoinRequest) -> String {
        userProfiles[request.userId]?.fullName ?? request.userName
    }
    
    /// Get avatar URL for request (prefer fresh profile, fallback to snapshot)
    func avatarURL(for request: JoinRequest) -> URL? {
        if let profile = userProfiles[request.userId], let urlStr = profile.avatarURL {
            return URL(string: urlStr)
        }
        if let urlStr = request.userAvatarURL {
            return URL(string: urlStr)
        }
        return nil
    }
    
    /// Get username handle (@username)
    func usernameHandle(for request: JoinRequest) -> String? {
        if let handle = userProfiles[request.userId]?.username {
            return "@" + handle
        }
        return nil
    }
}
