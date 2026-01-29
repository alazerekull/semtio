//
//  VideoTranscoder.swift
//  SemtioApp
//
//  Created for Video Upload Flow
//

import Foundation
import AVFoundation

class VideoTranscoder {
    
    enum TranscodeError: Error, LocalizedError {
        case exportSessionInitFailed
        case exportFailed(Error?)
        case cancelled
        case unknown
        
        var errorDescription: String? {
            switch self {
            case .exportSessionInitFailed: return "Could not initialize export session."
            case .exportFailed(let error): return "Export failed: \(error?.localizedDescription ?? "Unknown error")"
            case .cancelled: return "Export cancelled."
            case .unknown: return "An unknown error occurred during transcoding."
            }
        }
    }
    
    /// Transcodes a video file to MP4 with medium quality.
    /// - Parameter inputURL: Local file URL of the source video.
    /// - Returns: A tuple containing the output file URL (mp4) and the duration in seconds.
    func transcode(inputURL: URL) async throws -> (outputURL: URL, duration: Double) {
        let asset = AVAsset(url: inputURL)
        
        // Ensure we can read duration
        let duration = try await asset.load(.duration).seconds
        
        // Create output URL in temp directory
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        // Remove existing if any (unlikely with UUID)
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            throw TranscodeError.exportSessionInitFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            return (outputURL, duration)
        case .failed:
            throw TranscodeError.exportFailed(exportSession.error)
        case .cancelled:
            throw TranscodeError.cancelled
        default:
            throw TranscodeError.unknown
        }
    }
}
