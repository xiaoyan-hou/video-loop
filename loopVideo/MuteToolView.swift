//
//  MuteToolView.swift
//  loopVideo
//
//  Created by 狒狒 on 2025/10/19.
//

import SwiftUI
import AVKit
import PhotosUI

struct MuteToolView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var videoComposer = VideoComposer()
    @StateObject private var videoManager = VideoPlayerManager()
    @State private var showingImagePicker = false
    @State private var selectedVideos: [PhotosPickerItem] = []
    @State private var showingShareSheet = false
    @State private var videoToShare: URL?
    @State private var processedVideoURL: URL?
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("LoopClip")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            showingImagePicker = true
                        }) {
                            Image(systemName: "video")
                                .font(.title3)
                                .foregroundColor(.primary)
                        }
                        
                        Button(action: {
                            // Settings action
                        }) {
                            Image(systemName: "gear")
                                .font(.title3)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                if appState.hasImportedVideo {
                    // Video Preview
                    MuteVideoPreviewView()
                        .environmentObject(appState)
                        .environmentObject(videoManager)
                    
                    // Mute Controls
                    MuteControlsView(
                        onRemoveAudio: removeAudioFromCurrentVideo,
                        onSave: saveProcessedVideo
                    )
                    .environmentObject(appState)
                    
                } else {
                    // No Video State
                    MuteNoVideoStateView(showingImagePicker: $showingImagePicker)
                }
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedVideos, matching: .videos, preferredItemEncoding: .automatic, photoLibrary: .shared())
        .onChange(of: selectedVideos) { newValue in
            if !newValue.isEmpty {
                // 导入所有选中的视频
                loadVideos(from: newValue)
                // 清空选择，以便下一次导入
                selectedVideos.removeAll()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background, .inactive:
                // 应用进入后台或非活跃状态时，停止视频
                videoManager.stop()
            case .active:
                // 应用返回前台时不自动播放，让用户手动控制
                break
            @unknown default:
                break
            }
        }
        .onDisappear {
            // 视图消失时，停止播放
            videoManager.stop()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let videoURL = videoToShare {
                ShareSheet(activityItems: [videoURL])
            }
        }
        .alert(videoComposer.alertTitle, isPresented: $videoComposer.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(videoComposer.alertMessage)
        }
        .overlay(
            Group {
                if videoComposer.isProcessing {
                    VideoProcessingOverlay(progress: videoComposer.progress, message: videoComposer.statusMessage)
                }
            }
        )
    }
    
    // 移除当前视频的音频
    private func removeAudioFromCurrentVideo() {
        guard let currentURL = appState.currentVideoURL else { return }
        
        videoComposer.removeAudioFromVideo(videoURL: currentURL) { result in
            switch result {
            case .success(let silentVideoURL):
                self.processedVideoURL = silentVideoURL
                self.showSaveOptions(for: silentVideoURL)
                
            case .failure(let error):
                videoComposer.showError(error)
            }
        }
    }
    
    // 保存处理后的视频
    private func saveProcessedVideo() {
        guard let videoURL = processedVideoURL else {
            videoComposer.showError(VideoComposerError.exportFailed)
            return
        }
        
        videoComposer.saveToPhotos(videoURL: videoURL) { result in
            switch result {
            case .success:
                videoComposer.showSuccess(message: "Silent video saved to Photos successfully!")
            case .failure(let error):
                videoComposer.showError(error)
            }
        }
    }
    
    // 显示保存选项
    private func showSaveOptions(for videoURL: URL) {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Audio Removed",
                message: "Audio has been successfully removed from the video!",
                preferredStyle: .actionSheet
            )
            
            alert.addAction(UIAlertAction(title: "Save to Photos", style: .default) { _ in
                self.videoComposer.saveToPhotos(videoURL: videoURL) { result in
                    switch result {
                    case .success:
                        self.videoComposer.showSuccess(message: "Silent video saved to Photos successfully!")
                    case .failure(let error):
                        self.videoComposer.showError(error)
                    }
                }
            })
            
            alert.addAction(UIAlertAction(title: "Share/Export", style: .default) { _ in
                self.videoToShare = videoURL
                self.showingShareSheet = true
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let viewController = windowScene.windows.first?.rootViewController {
                viewController.present(alert, animated: true)
            }
        }
    }
    
    private func loadVideos(from items: [PhotosPickerItem]) {
        for item in items {
            item.loadTransferable(type: VideoTransferable.self) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let video):
                        if let video = video {
                            // 添加视频到AppState（视频在 Loop 和 Mute tab 之间共享）
                            self.appState.addVideo(video.url)
                        }
                    case .failure(let error):
                        print("Error loading video: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Mute Video Preview View
struct MuteVideoPreviewView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var videoManager: VideoPlayerManager
    
    var body: some View {
        VStack(spacing: 12) {
            // 当有2个或更多视频时，显示缩略图列表
            if appState.selectedVideoURLs.count >= 2 {
                MuteVideoThumbnailScrollView()
                    .environmentObject(appState)
                    .environmentObject(videoManager)
            }
            
            // 视频播放器区域
            if let currentURL = appState.currentVideoURL {
                MuteVideoPlayerView(videoURL: currentURL)
                    .environmentObject(videoManager)
                    .environmentObject(appState)
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 240)
                    .padding(.horizontal, 20)
                    .overlay(
                        VStack {
                            Image(systemName: "film")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("Video Player")
                                .foregroundColor(.gray)
                        }
                    )
            }
        }
    }
}

// MARK: - Mute Video Thumbnail Scroll View
struct MuteVideoThumbnailScrollView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var videoManager: VideoPlayerManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(appState.selectedVideoURLs.enumerated()), id: \.offset) { index, url in
                    MuteThumbnailCard(
                        url: url,
                        isCurrentVideo: index == appState.currentVideoIndex,
                        onTap: {
                            // 切换到选中的视频
                            appState.currentVideoIndex = index
                            videoManager.loadVideo(from: url)
                            videoManager.setMuted(appState.isMuted)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 80)
    }
}

// MARK: - Mute Thumbnail Card
struct MuteThumbnailCard: View {
    let url: URL
    let isCurrentVideo: Bool
    let onTap: () -> Void
    @State private var thumbnailImage: UIImage? = nil
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // 缩略图
                Group {
                    if let image = thumbnailImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                            )
                    }
                }
                .frame(width: 100, height: 70)
                .clipped()
                .cornerRadius(8)
                
                // 当前视频指示器
                if isCurrentVideo {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 3)
                        .frame(width: 100, height: 70)
                }
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func generateThumbnail() {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let time = CMTimeMake(value: 1, timescale: 1)
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            thumbnailImage = UIImage(cgImage: cgImage)
        } catch {
            print("Error generating thumbnail: \(error)")
        }
    }
}

// MARK: - Mute Video Player View
struct MuteVideoPlayerView: View {
    let videoURL: URL
    @EnvironmentObject var videoManager: VideoPlayerManager
    @EnvironmentObject var appState: AppState
    @State private var isPlaying = false
    
    var body: some View {
        VStack(spacing: 12) {
            // 视频播放器
            if let player = videoManager.player {
                ZStack {
                    VideoPlayer(player: player)
                        .frame(height: 240)
                        .cornerRadius(12)
                        .onTapGesture {
                            togglePlayPause()
                        }
                    
                    // 播放/暂停按钮
                    if !isPlaying {
                        Button(action: togglePlayPause) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 10)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // 控制栏
                HStack(spacing: 16) {
                    // 播放/暂停按钮
                    Button(action: togglePlayPause) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                    }
                    
                    // 进度条
                    VStack(spacing: 4) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 4)
                                
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: geometry.size.width * (videoManager.currentTime / max(videoManager.duration, 1)), height: 4)
                            }
                        }
                        .frame(height: 4)
                        
                        HStack {
                            Text(formatTime(videoManager.currentTime))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(formatTime(videoManager.duration))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 音量按钮
                    Button(action: {
                        appState.isMuted.toggle()
                        videoManager.setMuted(appState.isMuted)
                    }) {
                        Image(systemName: appState.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            loadVideo()
        }
        .onChange(of: videoURL) { newValue in
            loadVideo()
        }
        .onChange(of: videoManager.isPlaying) { newValue in
            isPlaying = newValue
        }
        .onDisappear {
            videoManager.stop()
        }
    }
    
    private func loadVideo() {
        videoManager.loadVideo(from: videoURL)
        videoManager.setMuted(appState.isMuted)
        isPlaying = false
    }
    
    private func togglePlayPause() {
        if isPlaying {
            videoManager.pause()
        } else {
            videoManager.play()
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Mute Controls View
struct MuteControlsView: View {
    @EnvironmentObject var appState: AppState
    let onRemoveAudio: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Preview Mute Toggle
            VStack(alignment: .leading, spacing: 12) {
                Text("Preview Options")
                    .font(.headline)
                    .padding(.horizontal, 20)
                
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: appState.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview Mute")
                            .font(.headline)
                        Text("Temporarily mute audio during playback")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $appState.isMuted)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
            
            // Remove Audio Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Export Options")
                    .font(.headline)
                    .padding(.horizontal, 20)
                
                VStack(spacing: 12) {
                    // Info Box
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        
                        Text("Permanently remove all audio tracks from the video. This creates a new silent video file.")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Remove Audio Button
                    Button(action: onRemoveAudio) {
                        HStack(spacing: 10) {
                            Image(systemName: "speaker.slash.fill")
                                .font(.system(size: 18))
                            Text("Remove All Audio")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 100)
    }
}

// MARK: - Mute No Video State View
struct MuteNoVideoStateView: View {
    @Binding var showingImagePicker: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "film")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
            
            // Text
            VStack(spacing: 8) {
                Text("No Video Selected")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Please import a video to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Usage Note
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Remove background noise from videos or use in situations requiring silent playback")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 20)
            
            // Privacy Note
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "shield")
                        .foregroundColor(.blue)
                    Text("Your video is processed locally, protecting your privacy")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 20)
            
            // Import Button with Multi-Select Info
            Button(action: {
                showingImagePicker = true
            }) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "photo")
                        Text("Import Videos")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(12)
                    
                    Text("Select multiple videos to import at once")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
}

#Preview {
    MuteToolView()
        .environmentObject(AppState())
}
