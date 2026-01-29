//
//  JoinRequest.swift
//  SemtioApp
//
//  Model for event join requests (request approval mode).
//

import Foundation

// MARK: - Join Request Status

enum JoinRequestStatus: String, Codable {
    case pending   // Beklemede
    case approved  // Onaylandı
    case rejected  // Reddedildi
    
    var localizedName: String {
        switch self {
        case .pending: return "Beklemede"
        case .approved: return "Onaylandı"
        case .rejected: return "Reddedildi"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        }
    }
}

// MARK: - Join Request Model

struct JoinRequest: Identifiable, Codable, Equatable {
    var id: String
    var eventId: String
    var userId: String
    var userName: String
    var userAvatarURL: String?
    var status: JoinRequestStatus
    var createdAt: Date
    var respondedAt: Date?
    var responseNote: String?  // Optional note from host
    
    // MARK: - Computed Properties
    
    var isPending: Bool { status == .pending }
    var isApproved: Bool { status == .approved }
    var isRejected: Bool { status == .rejected }
    
    // Time since request
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - Mock Data

extension JoinRequest {
    static let mock = JoinRequest(
        id: "req-1",
        eventId: "evt-1",
        userId: "user-1",
        userName: "Ali Veli",
        userAvatarURL: nil,
        status: .pending,
        createdAt: Date().addingTimeInterval(-3600),
        respondedAt: nil,
        responseNote: nil
    )
    
    static let mockList: [JoinRequest] = [
        JoinRequest(
            id: "req-1",
            eventId: "evt-1",
            userId: "user-1",
            userName: "Ali Veli",
            userAvatarURL: nil,
            status: .pending,
            createdAt: Date().addingTimeInterval(-3600),
            respondedAt: nil,
            responseNote: nil
        ),
        JoinRequest(
            id: "req-2",
            eventId: "evt-1",
            userId: "user-2",
            userName: "Ayşe Fatma",
            userAvatarURL: nil,
            status: .pending,
            createdAt: Date().addingTimeInterval(-7200),
            respondedAt: nil,
            responseNote: nil
        )
    ]
}
