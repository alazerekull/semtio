//
//  PinCrypto.swift
//  SemtioApp
//
//  Copyright © 2026 Oguzhan Cankaya ve Fikir Creative. All rights reserved.
//
//  Cryptographic utilities for PIN hashing using PBKDF2-SHA256.
//

import Foundation
import CommonCrypto

enum PinCrypto {

    // MARK: - Configuration

    /// Number of PBKDF2 iterations (120,000 for strong security)
    private static let iterations: UInt32 = 120_000

    /// Output key length in bytes (32 bytes = 256 bits for SHA256)
    private static let keyLength = 32

    /// Salt length in bytes (16 bytes = 128 bits)
    private static let saltLength = 16

    // MARK: - Public API

    /// Generates a cryptographically secure random salt
    /// - Returns: Random salt data (16 bytes)
    static func randomSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: saltLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, saltLength, &bytes)

        if status != errSecSuccess {
            // Fallback to arc4random if SecRandomCopyBytes fails
            for i in 0..<saltLength {
                bytes[i] = UInt8.random(in: 0...255)
            }
        }

        return Data(bytes)
    }

    /// Derives a key from a PIN using PBKDF2-HMAC-SHA256
    /// - Parameters:
    ///   - pin: The user's PIN (plaintext)
    ///   - salt: Random salt data
    /// - Returns: Derived key data (32 bytes), or nil on failure
    static func pbkdf2Hash(pin: String, salt: Data) -> Data? {
        guard let pinData = pin.data(using: .utf8) else { return nil }

        var derivedKey = [UInt8](repeating: 0, count: keyLength)

        let status = salt.withUnsafeBytes { saltBytes -> Int32 in
            pinData.withUnsafeBytes { pinBytes -> Int32 in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    pinBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                    pinData.count,
                    saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    iterations,
                    &derivedKey,
                    keyLength
                )
            }
        }

        guard status == kCCSuccess else {
            print("⚠️ PinCrypto: PBKDF2 derivation failed with status: \(status)")
            return nil
        }

        return Data(derivedKey)
    }

    /// Converts Data to hexadecimal string
    /// - Parameter data: Input data
    /// - Returns: Lowercase hex string representation
    static func hex(_ data: Data) -> String {
        return data.map { String(format: "%02x", $0) }.joined()
    }

    /// Converts hexadecimal string to Data
    /// - Parameter hex: Hex string (must be even length)
    /// - Returns: Data, or nil if invalid hex
    static func data(fromHex hex: String) -> Data? {
        var data = Data()
        var hexString = hex

        // Remove any spaces or formatting
        hexString = hexString.replacingOccurrences(of: " ", with: "")

        guard hexString.count % 2 == 0 else { return nil }

        var index = hexString.startIndex
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2)
            let byteString = String(hexString[index..<nextIndex])

            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)

            index = nextIndex
        }

        return data
    }

    // MARK: - Convenience

    /// Hashes a PIN and returns both the hash and salt as hex strings
    /// - Parameter pin: The user's PIN
    /// - Returns: Tuple of (hashHex, saltHex), or nil on failure
    static func hashPin(_ pin: String) -> (hash: String, salt: String)? {
        let salt = randomSalt()

        guard let hash = pbkdf2Hash(pin: pin, salt: salt) else {
            return nil
        }

        return (hex(hash), hex(salt))
    }

    /// Verifies a PIN against a stored hash and salt
    /// - Parameters:
    ///   - pin: The PIN to verify
    ///   - storedHash: The stored hash (hex string)
    ///   - storedSalt: The stored salt (hex string)
    /// - Returns: True if PIN matches
    static func verifyPin(_ pin: String, storedHash: String, storedSalt: String) -> Bool {
        guard let saltData = data(fromHex: storedSalt) else {
            print("⚠️ PinCrypto: Invalid salt hex")
            return false
        }

        guard let computedHash = pbkdf2Hash(pin: pin, salt: saltData) else {
            print("⚠️ PinCrypto: Failed to compute hash")
            return false
        }

        let computedHex = hex(computedHash)

        // Constant-time comparison to prevent timing attacks
        return constantTimeCompare(computedHex, storedHash)
    }

    /// Constant-time string comparison to prevent timing attacks
    private static func constantTimeCompare(_ a: String, _ b: String) -> Bool {
        guard a.count == b.count else { return false }

        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)

        var result: UInt8 = 0
        for i in 0..<aBytes.count {
            result |= aBytes[i] ^ bBytes[i]
        }

        return result == 0
    }
}
