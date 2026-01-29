//
//  UploadPostView.swift
//  SemtioApp
//
//  Created for Video Upload Flow
//

import SwiftUI
import PhotosUI
import AVKit

struct UploadPostView: View {
    @StateObject private var pickerViewModel = VideoPickerViewModel()
    @State private var caption: String = ""
    @State private var isUploading: Bool = false
    @State private var uploadProgress: Double = 0.0
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                if let videoURL = pickerViewModel.selectedVideoURL {
                    // Preview Area
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .frame(height: 300)
                        .cornerRadius(12)
                        .padding()
                        .overlay(alignment: .topTrailing) {
                            Button {
                                pickerViewModel.clearSelection()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.white, .black.opacity(0.5))
                                    .padding(8)
                            }
                        }
                    
                    // Caption
                    TextField("Bir şeyler yaz...", text: $caption)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    // Upload Info
                    if isUploading {
                        VStack(spacing: 8) {
                            ProgressView(value: uploadProgress, total: 1.0)
                            Text("Yükleniyor... \(Int(uploadProgress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                    
                    // Share Button
                    Button {
                        startUpload()
                    } label: {
                        if isUploading {
                            ProgressView()
                        } else {
                            Text("Paylaş")
                                .bold()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isUploading || caption.isEmpty)
                    .padding()
                    
                } else {
                    // Empty State / Picker Button
                    VStack(spacing: 20) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        
                        Text("Paylaşmak için bir video seç")
                            .font(.headline)
                        
                        PhotosPicker(selection: $pickerViewModel.selectedItem, matching: .videos) {
                            Text("Galeriden Seç")
                                .bold()
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("Yeni Gönderi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") {
                        dismiss()
                    }
                    .disabled(isUploading)
                }
            }
            .alert("Hata", isPresented: Binding(get: { pickerViewModel.errorMessage != nil }, set: { _ in pickerViewModel.errorMessage = nil })) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(pickerViewModel.errorMessage ?? "")
            }
            .disabled(pickerViewModel.isLoading) // Disable interactions while loading video from picker
        }
    }
    
    private func startUpload() {
        guard let url = pickerViewModel.selectedVideoURL else { return }
        
        isUploading = true
        uploadProgress = 0.0
        
        Task {
            do {
                let _ = try await PostUploadService.shared.uploadVideoPost(
                    caption: caption,
                    videoLocalURL: url
                ) { progress in
                    Task { @MainActor in
                        withAnimation {
                            uploadProgress = progress
                        }
                    }
                }
                
                // Success
                await MainActor.run {
                    isUploading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    pickerViewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
