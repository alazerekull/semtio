//
//  VideoThumbnailer.swift
//  SemtioApp
//
//  Created for Video Upload Flow
//

import Foundation
import AVFoundation
import UIKit

class VideoThumbnailer {
    
    enum ThumbnailError: Error {
        case generationFailed(Error)
        case dataConversionFailed
    }
    
    /// Generates a JPEG thumbnail from a video URL.
    /// - Parameters:
    ///   - url: Local file URL of the video.
    ///   - time: Time in seconds to capture (defaults to 0.5 or start).
    /// - Returns: JPEG Data with 0.75 compression.
    func generateThumbnail(from url: URL, at time: Double = 0.5) async throws -> Data {
        let asset = AVAsset(url: url)
        
        // Validate duration to ensure we don't seek past end
        let duration = try await asset.load(.duration).seconds
        let captureTime = min(time, duration / 2.0)
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true // Respect rotation
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        let timeObj = CMTime(seconds: captureTime, preferredTimescale: 600)
        
        do {
            let (image, _) = try await generator.image(at: timeObj)
            let uiImage = UIImage(cgImage: image)
            
            guard let data = uiImage.jpegData(compressionQuality: 0.75) else {
                throw ThumbnailError.dataConversionFailed
            }
            return data
        } catch {
            throw ThumbnailError.generationFailed(error)
        }
    }
}
