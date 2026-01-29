//
//  Attendance.swift
//  SemtioApp
//
//  Created for Events V2 Feature.
//

import Foundation

enum AttendanceStatus: String, Codable {
    case joined
    case pending // For private events waiting for approval
    case declined
    case left
}

struct Attendance: Identifiable, Codable {
    var id: String { "\(eventId)_\(userId)" } // Composite ID
    let eventId: String
    let userId: String
    let status: AttendanceStatus
    let joinedAt: Date
    let role: String // "host", "attendee", "moderator"
}
