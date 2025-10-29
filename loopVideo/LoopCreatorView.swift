//
//  LoopCreatorView.swift
//  loopVideo
//
//  Created by 狒狒 on 2025/10/19.
//

import SwiftUI
import AVKit
import PhotosUI

struct LoopCreatorView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var videoManager = VideoPlayerManager()
    @StateObject private var videoComposer = VideoComposer()
    @State private var showingImagePicker = false
    @State private var selectedVideos: [PhotosPickerItem] = []
    @State private var selectedThumbnailIndex: Int? = nil
    @State private var selectedVideoIndices: Set<Int> = []
    @State private var showingFullScreenPlayer = false
    @State private var showingShareSheet = false
    @State private var videoToShare: URL?
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - 固定在顶部
            HStack {
                Text("Smooth Loop")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
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
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            
            // 内容区域
            if appState.hasImportedVideo {
                    // 多视频缩略图横向滚动条
                    if appState.selectedVideoURLs.count > 1 {
                        VideoThumbnailScrollView(selectedVideoIndices: $selectedVideoIndices)
                            .environmentObject(appState)
                            .environmentObject(videoManager)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    }
                    
                    // 当前激活视频预览窗
                    CurrentVideoPreviewView(showingFullScreenPlayer: $showingFullScreenPlayer, selectedVideoIndices: $selectedVideoIndices)
                        .environmentObject(videoManager)
                        .environmentObject(appState)
                        .onChange(of: appState.isMuted) { newValue in
                            videoManager.setMuted(newValue)
                        }
                    
                    // Loop Controls
                    LoopControlsView(
                        selectedVideoIndices: $selectedVideoIndices, 
                        showingFullScreenPlayer: $showingFullScreenPlayer,
                        onCombineVideos: combineSelectedVideos,
                        onAddVideo: { showingImagePicker = true },
                        onRemoveVideo: removeSelectedVideos
                    )
                    .environmentObject(videoManager)
                    .environmentObject(appState)
                    
            } else {
                // No Video State
                NoVideoStateView(showingImagePicker: $showingImagePicker)
            }
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
        .fullScreenCover(isPresented: $showingFullScreenPlayer) {
            if let player = videoManager.player {
                FullScreenVideoPlayer(player: player, isPresented: $showingFullScreenPlayer)
                    .environmentObject(videoManager)
            }
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
            // 视频处理进度覆盖层
            Group {
                if videoComposer.isProcessing {
                    VideoProcessingOverlay(progress: videoComposer.progress, message: videoComposer.statusMessage)
                }
            }
        )
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
    }
    
    private func loadVideos(from items: [PhotosPickerItem]) {
        for item in items {
            item.loadTransferable(type: VideoTransferable.self) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let video):
                        if let video = video {
                            // 添加视频到AppState
                            self.appState.addVideo(video.url)
                            
                            // 不再自动加载视频，让用户点击缩略图后才加载
                        }
                    case .failure(let error):
                        print("Error loading video: \(error)")
                    }
                }
            }
        }
    }
    
    private func removeSelectedVideos() {
        if appState.selectedVideoURLs.count == 1 {
            // 只有一个视频时，删除当前视频
            appState.removeVideo(at: 0)
            selectedVideoIndices.removeAll()
        } else {
            // 有多个视频时，删除选中的视频
            if selectedVideoIndices.isEmpty {
                // 如果没有选中任何视频，删除当前播放的视频
                appState.removeVideo(at: appState.currentVideoIndex)
            } else {
                // 删除选中的视频（从后往前删除，避免索引变化）
                let sortedIndices = selectedVideoIndices.sorted(by: >)
                for index in sortedIndices {
                    appState.removeVideo(at: index)
                }
                selectedVideoIndices.removeAll()
            }
        }
    }
    
    private func combineSelectedVideos() {
        // 获取排序后的选中视频URL
        let selectedURLs = selectedVideoIndices.sorted().compactMap { index in
            appState.selectedVideoURLs.indices.contains(index) ? appState.selectedVideoURLs[index] : nil
        }
        
        guard selectedURLs.count >= 2 else {
            videoComposer.showError(VideoComposerError.noVideos)
            return
        }
        
        // 合并视频
        videoComposer.combineVideos(urls: selectedURLs) { result in
            switch result {
            case .success(let combinedURL):
                // 视频合并成功，显示保存选项
                self.showSaveOptions(for: combinedURL)
                
            case .failure(let error):
                videoComposer.showError(error)
            }
        }
    }
    
    private func showSaveOptions(for videoURL: URL) {
        // 确保在主线程上显示 UI
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Video Combined",
                message: "Your videos have been combined successfully!",
                preferredStyle: .actionSheet
            )
            
            // 保存到相册
            alert.addAction(UIAlertAction(title: "Save to Photos", style: .default) { _ in
                self.videoComposer.saveToPhotos(videoURL: videoURL) { result in
                    switch result {
                    case .success:
                        self.videoComposer.showSuccess(message: "Video saved to Photos successfully!")
                    case .failure(let error):
                        self.videoComposer.showError(error)
                    }
                }
            })
            
            // 分享/导出
            alert.addAction(UIAlertAction(title: "Share/Export", style: .default) { _ in
                self.videoToShare = videoURL
                self.showingShareSheet = true
            })
            
            // 取消
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            // 显示弹窗
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let viewController = windowScene.windows.first?.rootViewController {
                viewController.present(alert, animated: true)
            }
        }
    }
}

// MARK: - Video Preview View
struct VideoPreviewView: View {
    @Binding var showingFullScreenPlayer: Bool
    @EnvironmentObject var videoManager: VideoPlayerManager
    @EnvironmentObject var appState: AppState
    @State private var selectedThumbnailIndex: Int? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            // Video Thumbnail Display
            if let currentURL = appState.currentVideoURL {
                Button(action: {
                    // 点击缩略图进行选择
                    selectedThumbnailIndex = appState.currentVideoIndex
                    // 加载视频用于全屏播放
                    videoManager.loadVideo(from: currentURL)
                    videoManager.setMuted(appState.isMuted)
                }) {
                    VideoThumbnailView(url: currentURL)
                        .frame(height: 240)
                        .cornerRadius(12)
                        .overlay(
                            // 选中状态指示器
                            selectedThumbnailIndex == appState.currentVideoIndex ? 
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 3)
                                    .overlay(
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(Color.blue)
                                            .position(x: 30, y: 30)
                                    )
                            : nil
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 240)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .overlay(
                        VStack {
                            Image(systemName: "film")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("Video Thumbnail")
                                .foregroundColor(.gray)
                        }
                    )
            }
        }
    }
}

// MARK: - Video Thumbnail Scroll View
struct VideoThumbnailScrollView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var videoManager: VideoPlayerManager
    @Binding var selectedVideoIndices: Set<Int>
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(appState.selectedVideoURLs.enumerated()), id: \.offset) { index, url in
                    LoopCreatorThumbnailCard(
                        url: url,
                        isSelected: selectedVideoIndices.contains(index),
                        onTap: {
                            // 切换选中状态
                            if selectedVideoIndices.contains(index) {
                                selectedVideoIndices.remove(index)
                            } else {
                                selectedVideoIndices.insert(index)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Loop Creator Thumbnail Card
struct LoopCreatorThumbnailCard: View {
    let url: URL
    let isSelected: Bool
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
                .frame(width: 80, height: 60)
                .clipped()
                .cornerRadius(8)
                
                // 选中状态指示器
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 3)
                        .frame(width: 80, height: 60)
                    
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                                .background(Color.white, in: Circle())
                        }
                        Spacer()
                    }
                    .frame(width: 80, height: 60)
                }
                
                // 播放图标 - 完全居中
                ZStack {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.3), in: Circle())
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            generateThumbnail()
        }
    }
    
    private func generateThumbnail() {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 160, height: 120) // 2x for retina
        
        do {
            let time = CMTimeMake(value: 1, timescale: 1)
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            thumbnailImage = UIImage(cgImage: cgImage)
        } catch {
            print("Error generating thumbnail: \(error)")
        }
    }
}

// MARK: - Current Video Preview View
struct CurrentVideoPreviewView: View {
    @Binding var showingFullScreenPlayer: Bool
    @Binding var selectedVideoIndices: Set<Int>
    @EnvironmentObject var videoManager: VideoPlayerManager
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 12) {
            // 当前视频预览
            if let currentURL = appState.currentVideoURL {
                Button(action: {
                    // 使用多选视频的播放逻辑
                    if selectedVideoIndices.isEmpty {
                        // 如果没有选中任何视频，播放当前视频并进入全屏
                        videoManager.loadVideo(from: currentURL)
                        videoManager.setMuted(appState.isMuted)
                        showingFullScreenPlayer = true
                    } else {
                        // 播放选中的视频并进入全屏
                        // 将 Set 转换为排序后的数组，保证播放顺序与缩略图顺序一致
                        let selectedURLs = selectedVideoIndices.sorted().compactMap { index in
                            appState.selectedVideoURLs.indices.contains(index) ? appState.selectedVideoURLs[index] : nil
                        }
                        videoManager.setMuted(appState.isMuted)
                        videoManager.startLoopingSelectedVideos(selectedURLs)
                        showingFullScreenPlayer = true
                    }
                }) {
                    ZStack {
                        VideoThumbnailView(url: currentURL)
                            .frame(height: 180)
                            .cornerRadius(12)
                        
                        // 播放按钮覆盖层 - 完全居中
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // 占位符 - 完全居中
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 180)
                    
                    VStack(spacing: 12) {
                        Image(systemName: "film")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Video Selected")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        
        // 显示多选模式提示
        if !selectedVideoIndices.isEmpty {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                Text("Multi-selection mode: \(selectedVideoIndices.count) video(s) selected")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }
}

// MARK: - Video Thumbnail View
struct VideoThumbnailView: View {
    let url: URL
    @State private var thumbnailImage: UIImage? = nil
    
    var body: some View {
        Group {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

// MARK: - Loop Controls View
struct LoopControlsView: View {
    @EnvironmentObject var videoManager: VideoPlayerManager
    @EnvironmentObject var appState: AppState
    @Binding var selectedVideoIndices: Set<Int>
    @Binding var showingFullScreenPlayer: Bool
    @State private var selectedThumbnailIndex: Int? = nil
    let onCombineVideos: () -> Void
    let onAddVideo: () -> Void
    let onRemoveVideo: () -> Void
    
    var body: some View {
        if #available(iOS 17.0, *) {
            VStack(spacing: 16) {
                // Loop Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Loop Settings")
                        .font(.headline)
                        .padding(.horizontal, 20)
                    
                    HStack(spacing: 12) {
                        ForEach(LoopCount.allCases, id: \.self) { loopCount in
                            Button(action: {
                                videoManager.setLoopCount(loopCount)
                            }) {
                                Text(loopCount.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(videoManager.currentLoopCount == loopCount ? .white : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        videoManager.currentLoopCount == loopCount ? 
                                        Color.blue : Color(.systemGray6)
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Playback Controls
                VStack(alignment: .leading, spacing: 12) {
                    Text("Playback Controls")
                        .font(.headline)
                        .padding(.horizontal, 20)
                    
                    // Preview Button
                    Button(action: {
                        if selectedVideoIndices.isEmpty {
                            // 如果没有选中任何视频，播放当前视频并进入全屏
                            if let url = appState.currentVideoURL {
                                videoManager.loadVideo(from: url)
                                videoManager.setMuted(appState.isMuted)
                                showingFullScreenPlayer = true
                            }
                        } else {
                            // 播放选中的视频并进入全屏
                            // 将 Set 转换为排序后的数组，保证播放顺序与缩略图顺序一致
                            let selectedURLs = selectedVideoIndices.sorted().compactMap { index in
                                appState.selectedVideoURLs.indices.contains(index) ? appState.selectedVideoURLs[index] : nil
                            }
                            videoManager.setMuted(appState.isMuted)
                            videoManager.startLoopingSelectedVideos(selectedURLs)
                            showingFullScreenPlayer = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Preview Loop")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(appState.currentVideoURL == nil)
                    .opacity(appState.currentVideoURL == nil ? 0.5 : 1.0)
                    .padding(.horizontal, 20)
                    
                    // 显示选中视频数量
                    if !selectedVideoIndices.isEmpty {
                        Text("\(selectedVideoIndices.count) video(s) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                    }
                }
                
                // Additional Options
                VStack(spacing: 12) {
                    Button(action: {
                        onCombineVideos()
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Combine Videos")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .disabled(selectedVideoIndices.count < 2)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            // Export
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Export")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        Button(action: {
                            // Save loop
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Save Loop")
                            }
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                    }
                    
                    // Video Action Buttons (Add & Remove)
                    HStack(spacing: 12) {
                        // Add Video Button
                        Button(action: onAddVideo) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                Text("Add Video")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Remove Video Button
                        Button(action: onRemoveVideo) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 16))
                                Text("Remove")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .disabled(appState.selectedVideoURLs.isEmpty)
                        .opacity(appState.selectedVideoURLs.isEmpty ? 0.5 : 1.0)
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 100)
            // 监听父视图中选中的缩略图索引
            .onChange(of: appState.currentVideoIndex) { oldIndex, newIndex in
                // 当切换视频时，需要重置选中状态
                if videoManager.player == nil {
                    selectedThumbnailIndex = nil
                }
            }
        } else {
            // Fallback on earlier versions
        }
    }
}

// MARK: - No Video State View
struct NoVideoStateView: View {
    @Binding var showingImagePicker: Bool
    
    var body: some View {
        ZStack {
            // 背景颜色
            Color(white: 0.97)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 24) {
                    // Film Icon Container - 大圆形背景
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.85, green: 0.92, blue: 0.98)) // 浅蓝色背景
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "film")
                            .font(.system(size: 40, weight: .regular))
                            .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0)) // iOS 蓝色
                    }
                    
                    VStack(spacing: 8) {
                        // Title
                        Text("No Video Selected")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.black)
                        
                        // Subtitle
                        Text("Please import a video to get started")
                            .font(.system(size: 16))
                            .foregroundColor(Color(white: 0.6))
                    }
                    
                    // Info Box - 浅蓝色背景信息框
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                            .padding(.top, 1)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Perfect for mall promotions, exhibition demos, digital signage and other looping scenarios")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.93, green: 0.95, blue: 0.99)) // 浅蓝灰色背景
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    
                    // Import Button - 蓝色主按钮
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo")
                                .font(.system(size: 18, weight: .medium))
                            Text("Import from Gallery")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.0, green: 0.48, blue: 1.0)) // iOS 蓝色
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Full Screen Video Player
struct FullScreenVideoPlayer: View {
    let player: AVPlayer
    @Binding var isPresented: Bool
    @EnvironmentObject var videoManager: VideoPlayerManager
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            // 黑色背景
            Color.black.ignoresSafeArea()
            
            // 视频播放器 - 使用自定义的 AVPlayerViewController
            FullScreenAVPlayerView(player: player, showControls: $showControls)
                .ignoresSafeArea()
                .onAppear {
                    // 开始循环播放（使用 VideoPlayerManager 的循环逻辑）
                    videoManager.startLooping()
                    
                    // 3秒后自动隐藏控件
                    scheduleHideControls()
                }
                .onDisappear {
                    // 停止播放并清理
                    videoManager.stop()
                }
                .onTapGesture {
                    // 点击切换控件显示
                    toggleControls()
                }
            
            // 关闭按钮 - 跟随控件显示/隐藏
            if showControls {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            // 停止播放并关闭全屏
                            videoManager.stop()
                            isPresented = false
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.top, 50)
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showControls)
        .onChange(of: videoManager.isLooping) { newValue in
            // 当循环播放结束时，自动关闭全屏
            if !newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isPresented = false
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background, .inactive:
                // 应用进入后台时，停止播放并关闭全屏
                videoManager.stop()
                // 自动关闭全屏播放器
                isPresented = false
            case .active:
                // 应用返回前台时不自动播放，让用户手动控制
                break
            @unknown default:
                break
            }
        }
    }
    
    private func toggleControls() {
        showControls.toggle()
        
        if showControls {
            scheduleHideControls()
        } else {
            hideControlsTask?.cancel()
        }
    }
    
    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3秒
            if !Task.isCancelled {
                showControls = false
            }
        }
    }
}

// MARK: - Custom AVPlayer View with Controls
struct FullScreenAVPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    @Binding var showControls: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true
        
        // 保持当前的静音状态，不要修改
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.showsPlaybackControls = showControls
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}

// MARK: - Video Processing Overlay
struct VideoProcessingOverlay: View {
    let progress: Double
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 进度环
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 8)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: progress)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 8) {
                    Text("Processing Video")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

#Preview {
    LoopCreatorView()
        .environmentObject(AppState())
        .preferredColorScheme(.light)
}
