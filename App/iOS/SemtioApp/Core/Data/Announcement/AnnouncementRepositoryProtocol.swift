//
//  AnnouncementRepositoryProtocol.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

protocol AnnouncementRepositoryProtocol {
    /// Fetches all active announcements.
    func fetchActiveAnnouncements() async throws -> [Announcement]
    
    /// Fetches the latest active announcement (for banner display).
    func fetchLatestAnnouncement() async throws -> Announcement?
    
    /// Fetches a specific announcement by ID.
    func fetchAnnouncement(id: String) async throws -> Announcement?
}
