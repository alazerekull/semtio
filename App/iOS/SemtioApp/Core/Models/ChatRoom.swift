//
//  ChatRoom.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import FirebaseFirestore

struct ChatRoom: Identifiable, Codable {
    @DocumentID var id: String?
    var participants: [String]
    var lastMessage: String
    var type: String? // "direct" or "group"
    @ServerTimestamp var updatedAt: Date?
    
    // UI Helpers (Computed)
    var timeLabel: String {
        guard let date = updatedAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
