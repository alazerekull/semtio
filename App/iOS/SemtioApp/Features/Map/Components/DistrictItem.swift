//
//  DistrictItem.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

// MARK: - District Item Model (UI-Only)

struct DistrictItem: Identifiable, Equatable {
    let id: String
    let name: String              // "KADIKÖY", "BEYOĞLU" gibi
    let subplaces: [String]       // ["Moda", "Fenerbahçe", ...]
    let isUserDistrict: Bool      // kullanıcı konumu için true
    
    init(id: String = UUID().uuidString, name: String, subplaces: [String] = [], isUserDistrict: Bool = false) {
        self.id = id
        self.name = name
        self.subplaces = subplaces
        self.isUserDistrict = isUserDistrict
    }
}

// MARK: - Mock Data

extension DistrictItem {
    static let mockDistricts: [DistrictItem] = [
        DistrictItem(name: "PENDİK", subplaces: ["Kurtköy", "Kavakpınar"], isUserDistrict: false),
        DistrictItem(name: "KARTAL", subplaces: ["Kordonboyu", "Yakacık"], isUserDistrict: false),
        DistrictItem(name: "TUZLA", subplaces: ["Aydınlı", "İçmeler"], isUserDistrict: false),
        DistrictItem(name: "KADIKÖY", subplaces: ["Moda", "Fenerbahçe", "Yeldeğirmeni"], isUserDistrict: false),
        DistrictItem(name: "MALTEPE", subplaces: ["Bağlarbaşı", "Cevizli", "İdealtepe"], isUserDistrict: true), // USER LOCATION
        DistrictItem(name: "BEYOĞLU", subplaces: ["Taksim", "Cihangir", "Galata"], isUserDistrict: false),
        DistrictItem(name: "NİŞANTAŞI", subplaces: ["Teşvikiye", "Maçka"], isUserDistrict: false),
        DistrictItem(name: "BEŞİKTAŞ", subplaces: ["Bebek", "Ortaköy", "Levent"], isUserDistrict: false),
        DistrictItem(name: "AVCILAR", subplaces: ["Denizköşkler", "Cihangir Mah."], isUserDistrict: false),
    ]
    
    /// Returns districts sorted with user's district in the center
    static func centeredDistricts() -> [DistrictItem] {
        let districts = mockDistricts
        guard let userIndex = districts.firstIndex(where: { $0.isUserDistrict }) else {
            return districts
        }
        
        // Reorder so user's district is in the "visual center"
        var result: [DistrictItem] = []
        let userDistrict = districts[userIndex]
        let others = districts.filter { !$0.isUserDistrict }
        
        // Split above and below
        let aboveCount = others.count / 2
        let above = Array(others.prefix(aboveCount))
        let below = Array(others.dropFirst(aboveCount))
        
        result.append(contentsOf: above)
        result.append(userDistrict)
        result.append(contentsOf: below)
        
        return result
    }
}
