//
//  StoryCameraView.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI
import AVFoundation

struct StoryCameraView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var cameraService = CameraService()
    
    // Captured Media
    @Binding var selectedImage: UIImage?
    @Binding var selectedVideoURL: URL?
    
    // UI State
    @State private var isRecording = false
    @State private var zoomFactor: CGFloat = 1.0
    // Removed cameraMode
    
    // Gesture State
    @State private var dragStartTime: Date?
    @State private var pendingRecordingWorkItem: DispatchWorkItem?
    
    var onGallery: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 1. Camera Preview
            if cameraService.authorizationStatus == .authorized {
                CameraPreview(session: cameraService.session)
                    .ignoresSafeArea()
                    .gesture(
                        MagnificationGesture()
                            .onChanged { val in
                                zoomFactor = val
                            }
                    )
            } else {
                Text("Kamera izni gerekiyor.")
                    .foregroundColor(.white)
            }
            
            // 2. Controls
            VStack {
                // Top Bar
                HStack(spacing: 20) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    
                    Spacer()
                    
                    Button(action: { cameraService.toggleFlash() }) {
                        Image(systemName: cameraService.flashMode == .on ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                }
                .padding(.top, 50)
                .padding(.horizontal)
                
                Spacer()
                
                // Left Tools (Vertical)
                VStack(spacing: 24) {
                    Button {
                        // Create Text Mode
                        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1080, height: 1920))
                        let image = renderer.image { ctx in
                            UIColor.black.setFill()
                            ctx.fill(CGRect(x: 0, y: 0, width: 1080, height: 1920))
                        }
                        selectedImage = image
                    } label: {
                        ToolButton(icon: "textformat", label: "Aa")
                    }
                    
                    ToolButton(icon: "infinity", label: "Boomerang")
                    ToolButton(icon: "square.grid.2x2", label: "Layout")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
                
                Spacer()
                
                // Bottom Bar
                HStack(alignment: .center, spacing: 40) {
                    // Gallery
                    Button(action: onGallery) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "photo.on.rectangle")
                                    .foregroundColor(.white)
                            )
                    }
                    
                    // Capture Button
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .fill(isRecording ? Color.red : Color.white)
                            .frame(width: isRecording ? 40 : 70, height: isRecording ? 40 : 70)
                            .animation(.spring(), value: isRecording)
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if dragStartTime == nil {
                                    dragStartTime = Date()
                                    
                                    // Prepare work item to start recording after delay (Hold)
                                    let item = DispatchWorkItem {
                                        isRecording = true
                                        cameraService.startRecording { url in
                                            if let url = url {
                                                selectedVideoURL = url
                                            }
                                        }
                                    }
                                    pendingRecordingWorkItem = item
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
                                }
                            }
                            .onEnded { _ in
                                // Cancel pending recording start if released early
                                pendingRecordingWorkItem?.cancel()
                                pendingRecordingWorkItem = nil
                                dragStartTime = nil
                                
                                if isRecording {
                                    // Stop video
                                    isRecording = false
                                    cameraService.stopRecording()
                                } else {
                                    // Take photo (Tap)
                                    cameraService.takePhoto { image in
                                        if let img = image {
                                            selectedImage = img
                                        }
                                    }
                                }
                            }
                    )
                    
                    // Flip Camera
                    Button(action: { cameraService.switchCamera() }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                .padding(.bottom, 50)
            }
            
            // Removed Mode Selector VStack
        }
        .onAppear {
            cameraService.start()
        }
        .onDisappear {
            if isRecording {
                cameraService.stopRecording()
            }
            cameraService.stop()
        }
    }
}
// Removed CameraMode enum


struct ToolButton: View {
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .shadow(radius: 2)
            
            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
        }
    }
}

// Preview Wrapper
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {}
}

class VideoPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
