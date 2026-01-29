//
//  DeviceIdProvider.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Provides a stable device identifier persisted in Keychain.
//

import Foundation
import Security

final class DeviceIdProvider {
    
    // MARK: - Singleton
    
    static let shared = DeviceIdProvider()
    
    // MARK: - Constants
    
    private let keychainKey = "com.semtio.deviceId"
    private let userDefaultsKey = "semtio.deviceId.fallback"
    
    // MARK: - Cached Value
    
    private var cachedDeviceId: String?
    
    private init() {}
    
    // MARK: - Public
    
    /// Returns a stable device ID (persisted in Keychain, fallback to UserDefaults)
    var deviceId: String {
        if let cached = cachedDeviceId {
            return cached
        }
        
        // Try Keychain first
        if let keychainId = readFromKeychain() {
            cachedDeviceId = keychainId
            return keychainId
        }
        
        // Try UserDefaults fallback
        if let fallbackId = UserDefaults.standard.string(forKey: userDefaultsKey) {
            // Migrate to Keychain
            saveToKeychain(fallbackId)
            cachedDeviceId = fallbackId
            return fallbackId
        }
        
        // Generate new ID
        let newId = UUID().uuidString
        saveToKeychain(newId)
        UserDefaults.standard.set(newId, forKey: userDefaultsKey) // Backup
        cachedDeviceId = newId
        
        print("📱 DeviceIdProvider: Generated new device ID: \(newId)")
        return newId
    }
    
    // MARK: - Keychain Operations
    
    private func saveToKeychain(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ DeviceIdProvider: Failed to save to Keychain: \(status)")
        }
    }
    
    private func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
}
