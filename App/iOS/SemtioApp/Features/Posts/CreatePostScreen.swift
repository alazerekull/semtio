import SwiftUI
import PhotosUI
import AVKit

struct CreatePostScreen: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var userStore: UserStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel: CreatePostViewModel

    @State private var showExitAlert = false
    @State private var showMediaSourceActionSheet = false
    @State private var showUniversalPicker = false
    @State private var pickerSource: UIImagePickerController.SourceType = .photoLibrary

    init(postRepository: PostRepositoryProtocol? = nil) {
        let repo = postRepository ?? RepositoryFactory.makePostRepository()
        _viewModel = StateObject(wrappedValue: CreatePostViewModel(
            postRepository: repo,
            storageService: StorageService.shared
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                if viewModel.selectedImage != nil || viewModel.selectedVideoURL != nil {
                    mediaSelectedContent
                } else {
                    emptyStateContent
                }
            }
            .navigationTitle("Yeni Paylaşım")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        if viewModel.uploadState == .uploading {
                            // Do nothing while uploading
                        } else if viewModel.selectedImage != nil || viewModel.selectedVideoURL != nil {
                            showExitAlert = true
                        } else {
                            dismissAndReset()
                        }
                    }
                    .foregroundColor(AppColor.textPrimary)
                    .disabled(viewModel.uploadState == .uploading)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.publishPost(currentUser: userStore.currentUser)
                        }
                    } label: {
                        Text("Paylaş")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(canPublish ? Color.semtioPrimary : Color.gray.opacity(0.4))
                            )
                    }
                    .disabled(!canPublish || viewModel.uploadState == .uploading)
                }
            }
            .confirmationDialog("Medya Seç", isPresented: $showMediaSourceActionSheet) {
                Button("Kamera") {
                    pickerSource = .camera
                    showUniversalPicker = true
                }
                Button("Galeri") {
                    pickerSource = .photoLibrary
                    showUniversalPicker = true
                }
                Button("Vazgeç", role: .cancel) { }
            }
            .sheet(isPresented: $showUniversalPicker) {
                UniversalMediaPicker(sourceType: pickerSource) { videoURL, image in
                    if let videoURL = videoURL {
                        viewModel.setMedia(videoURL: videoURL)
                    } else if let image = image {
                        viewModel.setMedia(image: image)
                    }
                }
                .ignoresSafeArea()
            }
            .overlay {
                if viewModel.uploadState == .uploading {
                    uploadOverlay
                }
            }
            .alert(isPresented: Binding(
                get: {
                    if case .failed(_) = viewModel.uploadState { return true }
                    return false
                },
                set: { if !$0 { viewModel.uploadState = .idle } }
            )) {
                if case .failed(let error) = viewModel.uploadState {
                    return Alert(
                        title: Text("Paylaşım Yüklenemedi"),
                        message: Text(error.localizedDescription),
                        primaryButton: .default(Text("Tekrar Dene"), action: {
                            Task { await viewModel.publishPost(currentUser: userStore.currentUser) }
                        }),
                        secondaryButton: .cancel(Text("İptal"))
                    )
                } else {
                    return Alert(title: Text("Hata"))
                }
            }
            .alert("Değişiklikleri Sil?", isPresented: $showExitAlert) {
                Button("Sil", role: .destructive) { dismissAndReset() }
                Button("Vazgeç", role: .cancel) { }
            } message: {
                Text("Yaptığınız değişiklikler kaybolacak.")
            }
            .onChange(of: viewModel.uploadState) { _, state in
                if state == .success {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    dismissAndReset(success: true)
                }
            }
        }
    }

    // MARK: - Can Publish

    private var canPublish: Bool {
        viewModel.selectedImage != nil || viewModel.selectedVideoURL != nil
    }

    // MARK: - Empty State

    private var emptyStateContent: some View {
        VStack(spacing: 24) {
            Spacer()

            Button {
                showMediaSourceActionSheet = true
            } label: {
                VStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.semtioPrimary.opacity(0.08))
                            .frame(width: 100, height: 100)

                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.semtioPrimary)
                    }

                    Text("Fotoğraf veya Video Seç")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.semtioPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: Radius.lg)
                        .fill(AppColor.surface)
                        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
                )
                .padding(.horizontal, 32)
            }

            Text("Paylaşım yapmak için kamera veya galeriyi kullanın.")
                .font(.system(size: 14))
                .foregroundColor(AppColor.textSecondary)

            Spacer()
        }
    }

    // MARK: - Media Selected Content

    private var mediaSelectedContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Media Preview
                ZStack(alignment: .topTrailing) {
                    if viewModel.mediaType == .image, let image = viewModel.selectedImage {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 400)
                            .clipped()
                    } else if viewModel.mediaType == .video, let videoURL = viewModel.selectedVideoURL {
                        VideoPlayer(player: AVPlayer(url: videoURL))
                            .frame(maxWidth: .infinity)
                            .frame(height: 400)
                    }

                    // Remove media button
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.clearSelection()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(.black.opacity(0.5)))
                    }
                    .padding(12)

                    // Media type badge
                    if viewModel.mediaType == .video {
                        VStack {
                            HStack {
                                HStack(spacing: 4) {
                                    Image(systemName: "video.fill")
                                        .font(.caption2)
                                    Text("Video")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.black.opacity(0.5)))
                                .padding(12)

                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }
                .background(Color.black)
                .cornerRadius(Radius.md)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Caption field
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Bir açıklama ekle...", text: $viewModel.caption, axis: .vertical)
                        .font(.system(size: 16))
                        .lineLimit(1...6)
                        .padding(16)
                        .background(AppColor.surface)
                        .cornerRadius(Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(AppColor.border.opacity(0.5), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)

                // Change media button
                Button {
                    showMediaSourceActionSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14))
                        Text("Medyayı Değiştir")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.semtioPrimary)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(Color.semtioPrimary.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Upload Overlay

    private var uploadOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Animated circle progress
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 5)
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: viewModel.uploadProgress)
                        .stroke(Color.semtioPrimary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.uploadProgress)

                    Text("\(Int(viewModel.uploadProgress * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Text(uploadStatusText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)

                // Linear progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.semtioPrimary)
                            .frame(width: geo.size.width * viewModel.uploadProgress, height: 6)
                            .animation(.easeInOut(duration: 0.3), value: viewModel.uploadProgress)
                    }
                }
                .frame(height: 6)
                .padding(.horizontal, 32)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
            .padding(.horizontal, 48)
        }
    }

    private var uploadStatusText: String {
        let p = viewModel.uploadProgress
        if p < 0.15 {
            return "İşleniyor..."
        } else if p < 0.95 {
            return "Yükleniyor..."
        } else {
            return "Tamamlanıyor..."
        }
    }

    // MARK: - Actions

    private func dismissAndReset(success: Bool = false) {
        if success {
            Task {
                await appState.postFeed.refresh()
                await MainActor.run {
                    appState.postsChanged = true
                }
            }
        }
        viewModel.clearSelection()
        appState.dismissCreatePost()
    }
}
