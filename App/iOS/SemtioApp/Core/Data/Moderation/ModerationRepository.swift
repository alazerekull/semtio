//
//  ModerationRepository.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Report Type

enum ReportType: String {
    case post
    case comment
    case user
}

enum ReportReason: String, CaseIterable, Identifiable {
    case spam = "Spam / Yanıltıcı"
    case inappropriate = "Uygunsuz İçerik"
    case hate = "Nefret Söylemi / Hakaret"
    case fake = "Sahte Hesap / Taklit"
    case other = "Diğer"
    
    var id: String { rawValue }
}

// MARK: - Protocol

protocol ModerationRepositoryProtocol {
    func report(type: ReportType, targetId: String, reason: String) async throws
}

// MARK: - Implementation

final class FirestoreModerationRepository: ModerationRepositoryProtocol {
    private let db = Firestore.firestore()
    
    func report(type: ReportType, targetId: String, reason: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let data: [String: Any] = [
            "type": type.rawValue,
            "targetId": targetId,
            "reporterId": uid,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        let _ = try await db.collection("reports").addDocument(data: data)
    }
}

// MARK: - Mock

final class MockModerationRepository: ModerationRepositoryProtocol {
    func report(type: ReportType, targetId: String, reason: String) async throws {
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        print("Mock Report: \(type) \(targetId) for \(reason)")
    }
}
