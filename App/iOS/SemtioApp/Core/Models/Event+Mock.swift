//
//  Event+Mock.swift
//  SemtioApp
//
//  Created for Previews and Mock Repositories.
//

import Foundation

extension Event {
    static var mockActive: Event {
        Event(
            id: "1",
            title: "Test Event",
            description: nil,
            startDate: Date(),
            endDate: nil,
            locationName: "Istanbul",
            semtName: nil,
            hostUserId: "user1",
            participantCount: 5,
            coverColorHex: nil,
            category: .party,
            lat: 41.0,
            lon: 29.0,
            capacityLimit: 20,
            tags: [],
            isFeatured: false,
            createdBy: "user1",
            createdAt: Date(),
            district: nil,
            visibility: .public
        )
    }
    
    static var mockAlmostFull: Event {
        Event(
            id: "2",
            title: "Almost Full",
            description: nil,
            startDate: Date(),
            endDate: nil,
            locationName: "Istanbul",
            semtName: nil,
            hostUserId: "user1",
            participantCount: 17,
            coverColorHex: nil,
            category: .sport,
            lat: 41.0,
            lon: 29.0,
            capacityLimit: 20,
            tags: [],
            isFeatured: false,
            createdBy: "user1",
            createdAt: Date(),
            district: nil,
            visibility: .public
        )
    }
    
    static var mockFull: Event {
        Event(
            id: "3",
            title: "Full Event",
            description: nil,
            startDate: Date(),
            endDate: nil,
            locationName: "Istanbul",
            semtName: nil,
            hostUserId: "user1",
            participantCount: 20,
            coverColorHex: nil,
            category: .music,
            lat: 41.0,
            lon: 29.0,
            capacityLimit: 20,
            tags: [],
            isFeatured: false,
            createdBy: "user1",
            createdAt: Date(),
            district: nil,
            visibility: .public
        )
    }
}
