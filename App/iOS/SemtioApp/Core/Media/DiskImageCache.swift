//
//  DiskImageCache.swift
//  SemtioApp
//
//  Created for Performance Optimization on 2026-01-27.
//

import Foundation
import UIKit

final class DiskImageCache {
    static let shared = DiskImageCache()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache")
        
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func key(for url: URL) -> String {
        return url.absoluteString.data(using: .utf8)?.base64EncodedString().filter { $0.isLetter || $0.isNumber } ?? UUID().uuidString
    }
    
    func cache(_ image: UIImage, for url: URL) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let fileURL = cacheDirectory.appendingPathComponent(key(for: url))
        
        Task.detached(priority: .background) {
            try? data.write(to: fileURL)
        }
    }
    
    func get(for url: URL) -> UIImage? {
        let fileURL = cacheDirectory.appendingPathComponent(key(for: url))
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            return image
        }
        return nil
    }
}
