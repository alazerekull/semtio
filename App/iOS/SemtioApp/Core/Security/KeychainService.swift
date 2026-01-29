//
//  KeychainService.swift
//  SemtioApp
//
//  Copyright © 2026 Oguzhan Cankaya ve Fikir Creative. All rights reserved.
//
//  Secure Keychain wrapper for storing sensitive data.
//

import Foundation
import Security

final class KeychainService {

    // MARK: - Singleton

    static let shared = KeychainService()

    private init() {}

    // MARK: - Public API

    /// Saves data to Keychain
    /// - Parameters:
    ///   - data: The data to store
    ///   - service: Service identifier (e.g., "com.semtio.hiddenPin")
    ///   - account: Account identifier (e.g., user's UID)
    /// - Returns: True if successful
    @discardableResult
    func set(_ data: Data, service: String, account: String) -> Bool {
        // Delete existing item first
        delete(service: service, account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("⚠️ KeychainService: Failed to save - status: \(status)")
        }

        return status == errSecSuccess
    }

    /// Saves a string to Keychain
    @discardableResult
    func set(_ string: String, service: String, account: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return set(data, service: service, account: account)
    }

    /// Retrieves data from Keychain
    /// - Parameters:
    ///   - service: Service identifier
    ///   - account: Account identifier
    /// - Returns: The stored data, or nil if not found
    func get(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            return result as? Data
        }

        return nil
    }

    /// Retrieves a string from Keychain
    func getString(service: String, account: String) -> String? {
        guard let data = get(service: service, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Deletes an item from Keychain
    /// - Parameters:
    ///   - service: Service identifier
    ///   - account: Account identifier
    /// - Returns: True if successful or item didn't exist
    @discardableResult
    func delete(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Checks if an item exists in Keychain
    func exists(service: String, account: String) -> Bool {
        return get(service: service, account: account) != nil
    }

    /// Updates an existing item in Keychain
    @discardableResult
    func update(_ data: Data, service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            // Item doesn't exist, create it
            return set(data, service: service, account: account)
        }

        return status == errSecSuccess
    }
}

// MARK: - Constants

extension KeychainService {
    enum Service {
        static let hiddenPinHash = "com.semtio.hiddenPin.hash"
        static let hiddenPinSalt = "com.semtio.hiddenPin.salt"
    }
}
