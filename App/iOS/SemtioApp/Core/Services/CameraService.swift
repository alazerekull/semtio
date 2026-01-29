//
//  CameraService.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import AVFoundation
import UIKit
import Combine

class CameraService: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate {
    @Published var session = AVCaptureSession()
    @Published var isSessionRunning = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    
    private let sessionQueue = DispatchQueue(label: "com.semtio.cameraQueue")
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureMovieFileOutput()
    
    // Front/Back
    @Published var position: AVCaptureDevice.Position = .back
    
    // Video Completion
    var onVideoCaptured: ((URL?) -> Void)?
    
    override init() {
        super.init()
        checkPermissions()
    }

    func checkPermissions() {
        let videoStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let audioStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        if videoStatus == .authorized {
            // Audio might be undetermined or denied, but we proceed with video
            self.authorizationStatus = .authorized
            setupSession()
            return
        }
        
        if videoStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self = self else { return }
                if granted {
                    // Check Audio
                    AVCaptureDevice.requestAccess(for: .audio) { [weak self] audioGranted in
                        Task { @MainActor [weak self] in
                            self?.authorizationStatus = audioGranted ? .authorized : .authorized // Allow video even if audio denied? Ideally yes
                            self?.setupSession()
                        }
                    }
                } else {
                    Task { @MainActor [weak self] in self?.authorizationStatus = .denied }
                }
            }
        } else if videoStatus == .denied {
            self.authorizationStatus = .denied
        }
    }
    
    func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high
            self.session.automaticallyConfiguresApplicationAudioSession = false // Manual control
            
            // Configure Audio Session
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetooth])
                try session.setActive(true)
            } catch {
                print("Failed to set audio session category: \(error)")
            }
            
            // Add Inputs
            self.addInput(position: self.position)
            
            // Add Audio Input
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                do {
                    let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                    if self.session.canAddInput(audioInput) {
                        self.session.addInput(audioInput)
                    }
                } catch {
                    print("Could not add audio device input to the session")
                }
            }
            
            // Add Outputs
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            if self.session.canAddOutput(self.videoOutput) {
                 self.session.addOutput(self.videoOutput)
            }
            
            self.session.commitConfiguration()
        }
    }

    private func addInput(position: AVCaptureDevice.Position) {
        // Remove existing input
        if let currentInput = videoDeviceInput {
            session.removeInput(currentInput)
        }
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else { return }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                videoDeviceInput = input
            }
        } catch {
            print("CameraService: Failed to create input: \(error)")
        }
    }
    
    func start() {
        guard authorizationStatus == .authorized else { return }
        sessionQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
            Task { @MainActor in self.isSessionRunning = true }
        }
    }
    
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
            Task { @MainActor in self.isSessionRunning = false }
        }
    }
    
    func switchCamera() {
        position = (position == .back) ? .front : .back
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            self.addInput(position: self.position)
            self.session.commitConfiguration()
            
            // Re-apply connection settings if needed (like mirroring for front camera)
            if let connection = self.videoOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
                if self.position == .front {
                    connection.isVideoMirrored = true
                } else {
                    connection.isVideoMirrored = false
                }
            }
        }
    }
    
    func toggleFlash() {
        flashMode = (flashMode == .off) ? .on : .off
        // Toggle Torch for video preview (User requested flash to work)
        guard let device = videoDeviceInput?.device, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            if device.torchMode == .off {
                try device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used")
        }
    }
    
    // MARK: - Capture
    
    func takePhoto(completion: @escaping (UIImage?) -> Void) {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        
        // Delegate wrapper to handle callbacks
        let delegate = PhotoCaptureProcessor { image in
            Task { @MainActor in
                completion(image)
            }
        }
        self.photoCaptureDelegates[settings.uniqueID] = delegate // Retain
        self.photoOutput.capturePhoto(with: settings, delegate: delegate)
    }
    
    // MARK: - Video Recording
    
    func startRecording(completion: @escaping (URL?) -> Void) {
        self.onVideoCaptured = completion
        
        guard !videoOutput.isRecording else { return }
        
        let outputFileName = NSUUID().uuidString
        let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
        let outputURL = URL(fileURLWithPath: outputFilePath)
        
        videoOutput.startRecording(to: outputURL, recordingDelegate: self)
    }
    
    func stopRecording() {
        if videoOutput.isRecording {
            videoOutput.stopRecording()
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if let error = error {
                print("Error recording movie: \(error.localizedDescription)")
                self.onVideoCaptured?(nil)
            } else {
                self.onVideoCaptured?(outputFileURL)
            }
            self.onVideoCaptured = nil
        }
    }
    
    // Store delegates to keep them alive during capture
    private var photoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
}

class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (UIImage?) -> Void
    
    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            completion(image)
        } else {
            completion(nil)
        }
    }
}
