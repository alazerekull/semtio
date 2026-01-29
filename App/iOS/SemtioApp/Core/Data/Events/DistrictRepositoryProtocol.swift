//
//  DistrictRepositoryProtocol.swift
//  SemtioApp
//
//  Created for Semtio Map Refactor.
//

import Foundation

protocol DistrictRepositoryProtocol {
    func searchDistricts(query: String) async throws -> [District]
    func nearbyDistricts(lat: Double, lng: Double) async throws -> [District]
    func getAllDistricts() async throws -> [District]
}

class MockDistrictRepository: DistrictRepositoryProtocol {
    private let mockDistricts: [District] = [
        District(id: "kadikoy", name: "Kadıköy", centerLat: 40.9910, centerLng: 29.0220),
        District(id: "besiktas", name: "Beşiktaş", centerLat: 41.0428, centerLng: 29.0076),
        District(id: "sisli", name: "Şişli", centerLat: 41.0617, centerLng: 28.9858),
        District(id: "beyoglu", name: "Beyoğlu", centerLat: 41.0335, centerLng: 28.9778),
        District(id: "uskudar", name: "Üsküdar", centerLat: 41.0267, centerLng: 29.0152),
        District(id: "fatih", name: "Fatih", centerLat: 41.0182, centerLng: 28.9482),
        District(id: "atasehir", name: "Ataşehir", centerLat: 40.9926, centerLng: 29.1239),
        District(id: "maltepe", name: "Maltepe", centerLat: 40.9497, centerLng: 29.1350)
    ]
    
    func searchDistricts(query: String) async throws -> [District] {
        if query.isEmpty { return mockDistricts }
        return mockDistricts.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    
    func nearbyDistricts(lat: Double, lng: Double) async throws -> [District] {
        // Simple mock: return all (sorted by distance logic could be added)
        return mockDistricts
    }
    
    func getAllDistricts() async throws -> [District] {
        return mockDistricts
    }
}
