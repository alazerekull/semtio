//
//  UsageLimitService.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//
//  Tracks daily usage limits for free tier users, namespaced per user.
//

import Foundation

final class UsageLimitService {
    
    // MARK: - Constants
    
    /// Free tier daily limit for event creation
    static let freeEventLimit = 1
    
    // MARK: - Singleton
    
    static let shared = UsageLimitService()
    
    private let defaults: UserDefaults
    private let dateFormatter: DateFormatter
    private var currentUid: String?
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
    }
    
    // MARK: - User Management
    
    /// Sets the current user UID for namespaced usage tracking
    func setUser(uid: String?) {
        currentUid = uid
        if let uid = uid {
            print("📊 UsageLimitService: Set user to \(uid)")
        } else {
            print("📊 UsageLimitService: Cleared user")
        }
    }
    
    // MARK: - Keys (User-Namespaced)
    
    private func lastCreateDayKey(for uid: String) -> String {
        "usage.lastCreateDay.\(uid)"
    }
    
    private func dailyCreateCountKey(for uid: String) -> String {
        "usage.dailyCreateCount.\(uid)"
    }
    
    // MARK: - Event Creation Limit
    
    /// Checks if user can create an event
    /// - Parameter isPremium: Whether user has premium subscription
    /// - Returns: true if user can create, false if limit reached or no user set
    func canCreateEvent(isPremium: Bool) -> Bool {
        // Premium users have unlimited access
        if isPremium { return true }
        
        // No user set - cannot create
        guard let uid = currentUid else {
            print("📊 UsageLimitService: No user set, denying create")
            return false
        }
        
        // Reset count if day changed
        resetIfDayChanged(for: uid)
        
        let count = defaults.integer(forKey: dailyCreateCountKey(for: uid))
        return count < Self.freeEventLimit
    }
    
    /// Records that an event was created (call after successful creation)
    func recordEventCreated() {
        guard let uid = currentUid else {
            print("📊 UsageLimitService: No user set, cannot record")
            return
        }
        
        resetIfDayChanged(for: uid)
        
        let countKey = dailyCreateCountKey(for: uid)
        let dayKey = lastCreateDayKey(for: uid)
        
        let count = defaults.integer(forKey: countKey)
        defaults.set(count + 1, forKey: countKey)
        defaults.set(todayString, forKey: dayKey)
        
        print("📊 UsageLimitService: Event created for \(uid). Daily count: \(count + 1)/\(Self.freeEventLimit)")
    }
    
    /// Returns remaining event creations for today
    func remainingEventCreations(isPremium: Bool) -> Int {
        if isPremium { return .max }
        
        guard let uid = currentUid else { return 0 }
        
        resetIfDayChanged(for: uid)
        let count = defaults.integer(forKey: dailyCreateCountKey(for: uid))
        return max(0, Self.freeEventLimit - count)
    }
    
    // MARK: - Private
    
    private var todayString: String {
        dateFormatter.string(from: Date())
    }
    
    private func resetIfDayChanged(for uid: String) {
        let dayKey = lastCreateDayKey(for: uid)
        let countKey = dailyCreateCountKey(for: uid)
        
        let lastDay = defaults.string(forKey: dayKey) ?? ""
        
        if lastDay != todayString {
            defaults.set(0, forKey: countKey)
            defaults.set(todayString, forKey: dayKey)
            print("📊 UsageLimitService: New day detected for \(uid). Reset daily count.")
        }
    }
    
    // MARK: - Testing/Preview Support
    
    /// Resets all usage data for current user (for testing)
    func reset() {
        guard let uid = currentUid else { return }
        defaults.removeObject(forKey: lastCreateDayKey(for: uid))
        defaults.removeObject(forKey: dailyCreateCountKey(for: uid))
    }
}
