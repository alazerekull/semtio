//
//  ImagePipeline.swift
//  SemtioApp
//
//  Created for Performance Optimization on 2026-01-27.
//

import UIKit
import Combine

/// Centralized Image Loading Actor
/// Handles: Memory Cache, Disk Cache, Downsampling, De-duplication
actor ImagePipeline {
    static let shared = ImagePipeline()
    
    private var memoryCache = NSCache<NSString, UIImage>()
    private var activeTasks: [URL: Task<UIImage?, Error>] = [:]
    
    private init() {
        memoryCache.countLimit = 100 // Example limit
    }
    
    func image(for url: URL, targetSize: CGSize? = nil) async throws -> UIImage? {
        let key = url.absoluteString as NSString
        
        // 1. Memory Cache
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }
        
        // 2. Coalesce Requests
        if let existingTask = activeTasks[url] {
            return try await existingTask.value
        }
        
        let task = Task<UIImage?, Error> {
            // 3. Disk Cache
            if let diskImage = DiskImageCache.shared.get(for: url) {
                memoryCache.setObject(diskImage, forKey: key)
                return diskImage
            }
            
            // 4. Download & Downsample
            return try await downloadAndDownsample(url: url, targetSize: targetSize)
        }
        
        activeTasks[url] = task
        
        // Cleanup after finish
        let result = try await task.value
        activeTasks[url] = nil
        return result
    }
    
    private func downloadAndDownsample(url: URL, targetSize: CGSize?) async throws -> UIImage? {
        PerformanceLogger.shared.start("DownloadImage", category: "Media")
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        PerformanceLogger.shared.end("DownloadImage", category: "Media")
        PerformanceLogger.shared.start("DecodeImage", category: "Media")
        
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        
        let options: [CFString: Any]
        if let size = targetSize {
            // Downsample
            let maxPixel = max(size.width, size.height)
            options = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel
            ]
        } else {
            options = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
        }
        
        let result: UIImage?
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            result = UIImage(cgImage: cgImage)
        } else {
            result = UIImage(data: data)
        }
        
        PerformanceLogger.shared.end("DecodeImage", category: "Media")
        
        if let validInfo = result {
            memoryCache.setObject(validInfo, forKey: url.absoluteString as NSString)
            DiskImageCache.shared.cache(validInfo, for: url)
        }
        
        return result
    }
}
