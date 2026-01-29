//
//  EventFilter.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

struct EventFilter {
    var category: EventCategory?
    var district: String?
    var featuredOnly: Bool = false
    var activeOnly: Bool = false
    var dateStart: Date?
    var dateEnd: Date?
    var tags: [String]?
    var createdBy: String?
    var limit: Int?
    
    static let all = EventFilter()
    
    static func featured() -> EventFilter {
        EventFilter(featuredOnly: true)
    }
    
    static func active() -> EventFilter {
        EventFilter(activeOnly: true)
    }
    
    static func forCategory(_ category: EventCategory) -> EventFilter {
        EventFilter(category: category)
    }
    
    static func forDistrict(_ district: String) -> EventFilter {
        EventFilter(district: district)
    }
    
    static func forInterests(_ interests: [String]) -> EventFilter {
        // Map interests to categories or tags
        // For now, we'll match by category name
        EventFilter(tags: interests)
    }
}
