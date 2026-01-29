//
//  ShareCodeGenerator.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation

enum ShareCodeGenerator {
    
    private static let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    private static let codeLength = 11
    
    /// Generates a random 11-character alphanumeric code (A-Z, 0-9).
    static func generate() -> String {
        String((0..<codeLength).map { _ in
            characters.randomElement()!
        })
    }
    
    /// Generates a unique code by checking against existing codes.
    /// Retries up to `maxRetries` times to avoid collision.
    static func generateUnique(existingCodes: Set<String>, maxRetries: Int = 10) -> String {
        var code = generate()
        var attempts = 0
        
        while existingCodes.contains(code) && attempts < maxRetries {
            code = generate()
            attempts += 1
        }
        
        return code
    }
}
