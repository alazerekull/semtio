//
//  ShareService.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import UIKit

final class ShareService {
    static let shared = ShareService()
    
    private init() {}
    
    // MARK: - Deep Link Constants
    
    static let deepLinkScheme = "semtio"
    static let webBaseURL = "https://semtio.app"
    
    // MARK: - Event Sharing
    
    /// Generates deep link for an event
    static func eventDeepLink(eventId: String) -> URL? {
        URL(string: "\(deepLinkScheme)://event/\(eventId)")
    }
    
    /// Generates web link for an event
    static func eventWebLink(eventId: String) -> URL? {
        URL(string: "\(webBaseURL)/event/\(eventId)")
    }
    
    /// Share an event with UIActivityViewController
    func shareEvent(_ event: Event, from viewController: UIViewController? = nil) {
        let webLink = ShareService.eventWebLink(eventId: event.id)
        
        // Build location text
        var locationText = "📍 "
        if let district = event.district, let location = event.locationName {
            locationText += "\(district) • \(location)"
        } else if let district = event.district {
            locationText += district
        } else if let location = event.locationName {
            locationText += location
        } else {
            locationText += "Konum belirtilmedi"
        }
        
        // Format date/time
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        
        var timeText = "🕐 "
        if Calendar.current.isDateInToday(event.startDate) {
            formatter.dateFormat = "'Bugün' HH:mm"
        } else if Calendar.current.isDateInTomorrow(event.startDate) {
            formatter.dateFormat = "'Yarın' HH:mm"
        } else {
            formatter.dateFormat = "d MMMM, HH:mm"
        }
        timeText += formatter.string(from: event.startDate)
        
        let text = """
        🎉 \(event.title)
        
        \(locationText)
        \(timeText)
        
        Semtio'da katıl!
        \(webLink?.absoluteString ?? "")
        """
        
        var items: [Any] = [text]
        if let link = webLink {
            items.append(link)
        }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Resolve target view controller
        let targetVC = viewController ?? topViewController()
        
        // Configure popover for iPad (if needed)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = targetVC?.view
            if let bounds = targetVC?.view.bounds {
                popover.sourceRect = CGRect(x: bounds.midX, y: bounds.midY, width: 0, height: 0)
            }
            popover.permittedArrowDirections = []
        }
        
        // Present
        targetVC?.present(activityVC, animated: true)
    }
    
    /// Share event from SwiftUI View
    @MainActor
    func shareEvent(_ event: Event) {
        shareEvent(event, from: topViewController())
    }
    
    // MARK: - Helpers
    
    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else {
            return nil
        }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }
}
