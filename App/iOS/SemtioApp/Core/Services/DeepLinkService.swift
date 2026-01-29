//
//  DeepLinkService.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Handles parsing and routing of Semtio deep links.
//
//  Example URLs:
//  - semtio://event/ABC123          (custom scheme)
//  - https://semtio.app/event/ABC123 (universal link)
//  - semtio://chat/THREAD_ID        (chat deep link)
//  - https://semtio.app/chat/THREAD_ID (chat universal link)
//

import Foundation
import SwiftUI
import Combine

// MARK: - Deep Link Destination

/// Represents a parsed deep link destination
enum DeepLinkDestination: Equatable {
    case eventDetail(eventId: String)
    case userProfile(userId: String)
    case chat(threadId: String)
    case post(postId: String, ownerId: String? = nil, username: String? = nil)
    case invite(token: String)
    case none
    
    var eventId: String? {
        if case .eventDetail(let id) = self { return id }
        return nil
    }
    
    var threadId: String? {
        if case .chat(let id) = self { return id }
        return nil
    }
    
    var postId: String? {
        if case .post(let id, _, _) = self { return id }
        return nil
    }
}

// MARK: - Deep Link Service

final class DeepLinkService: ObservableObject {
    
    // MARK: - Constants
    
    static let customScheme = "semtio"
    static let webHost = "semtio.app"
    
    // MARK: - Published State
    
    @Published var activeDestination: DeepLinkDestination = .none
    
    init() {}
    
    // MARK: - Parsing
    
    /// Parse URL and extract deep link destination
    /// Supports both custom scheme (semtio://) and universal links (https://semtio.app)
    func parse(_ url: URL) -> DeepLinkDestination {
        // Custom scheme: semtio://event/{eventId}
        if url.scheme == Self.customScheme {
            return parseCustomScheme(url)
        }
        
        // Universal link: https://semtio.app/event/{eventId}
        if url.host == Self.webHost {
            return parseWebLink(url)
        }
        
        return .none
    }
    
    /// Parse custom scheme URL: semtio://event/{eventId}, semtio://chat/{threadId}
    private func parseCustomScheme(_ url: URL) -> DeepLinkDestination {
        guard let host = url.host else { return .none }
        
        switch host {
        case "event":
            // semtio://event/{eventId} -> path is /{eventId}
            let eventId = url.pathComponents.first { $0 != "/" }
            if let eventId = eventId, !eventId.isEmpty {
                return .eventDetail(eventId: eventId)
            }
            
        case "chat":
            // semtio://chat/{threadId}
            let threadId = url.pathComponents.first { $0 != "/" }
            if let threadId = threadId, !threadId.isEmpty {
                return .chat(threadId: threadId)
            }
            
        case "user", "profile":
            let userId = url.pathComponents.first { $0 != "/" }
            if let userId = userId, !userId.isEmpty {
                return .userProfile(userId: userId)
            }
            
        case "post":
            let postId = url.pathComponents.first { $0 != "/" }
            if let postId = postId, !postId.isEmpty {
                // Check for ownerId query param
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let ownerId = components?.queryItems?.first(where: { $0.name == "ownerId" })?.value
                let username = components?.queryItems?.first(where: { $0.name == "username" })?.value
                return .post(postId: postId, ownerId: ownerId, username: username)
            }
            
        case "invite":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let token = components.queryItems?.first(where: { $0.name == "token" })?.value {
                return .invite(token: token)
            }
            
        default:
            break
        }
        
        return .none
    }
    
    /// Parse web URL: https://semtio.app/event/{eventId}
    private func parseWebLink(_ url: URL) -> DeepLinkDestination {
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        guard pathComponents.count >= 2 else { return .none }
        
        let type = pathComponents[0]
        let id = pathComponents[1]
        
        switch type {
        case "event":
            return .eventDetail(eventId: id)
            
        case "chat":
            return .chat(threadId: id)
            
        case "user", "profile":
            return .userProfile(userId: id)
            
        default:
            return .none
        }
    }
    
    // MARK: - Notification Payload Parsing
    
    /// Parse push notification userInfo into a destination
    func parseNotification(_ userInfo: [AnyHashable: Any]) -> DeepLinkDestination {
        guard let type = userInfo["type"] as? String else {
            return .none
        }
        
        switch type {
        case "chat":
            if let threadId = userInfo["threadId"] as? String, !threadId.isEmpty {
                return .chat(threadId: threadId)
            }
            
        case "event":
            if let eventId = userInfo["eventId"] as? String, !eventId.isEmpty {
                return .eventDetail(eventId: eventId)
            }
            
        case "post":
            if let postId = userInfo["postId"] as? String, !postId.isEmpty {
                return .post(postId: postId)
            }
            
        default:
            break
        }
        
        return .none
    }
    
    // MARK: - Handling
    
    /// Handle incoming URL and set active destination
    func handle(_ url: URL) {
        let destination = parse(url)
        DispatchQueue.main.async {
            self.activeDestination = destination
            if case .none = destination {
                print("⚠️ DeepLinkService: Unknown URL: \(url)")
            } else {
                print("🔗 DeepLinkService: Parsed destination: \(destination)")
            }
        }
    }
    
    /// Clear active destination after navigation
    func clearDestination() {
        DispatchQueue.main.async {
            self.activeDestination = .none
        }
    }
}

// MARK: - Legacy Compatibility

/// Legacy enum for backward compatibility
enum DeepLink {
    case event(id: String)
    case unknown
    
    init(from destination: DeepLinkDestination) {
        switch destination {
        case .eventDetail(let eventId):
            self = .event(id: eventId)
        default:
            self = .unknown
        }
    }
}
