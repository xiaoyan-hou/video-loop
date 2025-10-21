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
    @State private var showingImagePicker = false
    @State private var selectedVideos: [PhotosPickerItem] = []
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
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
                    MuteVideoPreviewView(
                        player: $player,
                        isPlaying: $isPlaying,
                        currentTime: $currentTime,
                        duration: $duration
                    )
                    .environmentObject(appState)
                    
                    // Video Navigation and Controls
                    HStack(spacing: 12) {
                        // Previous Video Button
                        Button(action: {
                            appState.previousVideo()
                            if let url = appState.currentVideoURL {
                                loadVideoPlayer(from: url)
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                                .foregroundColor(appState.selectedVideoURLs.count > 1 ? .blue : .gray.opacity(0.5))
                                .frame(width: 44, height: 44)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(22)
                        }
                        .disabled(appState.selectedVideoURLs.count <= 1)
                        
                        // Video Counter
                        if appState.selectedVideoURLs.count > 1 {
                            Text("\(appState.currentVideoIndex + 1) / \(appState.selectedVideoURLs.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        Spacer()
                        
                        // Next Video Button
                        Button(action: {
                            appState.nextVideo()
                            if let url = appState.currentVideoURL {
                                loadVideoPlayer(from: url)
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.headline)
                                .foregroundColor(appState.selectedVideoURLs.count > 1 ? .blue : .gray.opacity(0.5))
                                .frame(width: 44, height: 44)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(22)
                        }
                        .disabled(appState.selectedVideoURLs.count <= 1)
                        
                        // Remove Current Video Button
                        Button(action: {
                            appState.removeVideo(at: appState.currentVideoIndex)
                            if let url = appState.currentVideoURL {
                                loadVideoPlayer(from: url)
                            } else {
                                player = nil
                            }
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove")
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    
                    // Mute Controls
                    MuteControlsView()
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
                // 应用进入后台时，暂停视频
                player?.pause()
                isPlaying = false
            case .active:
                // 应用返回前台时不自动播放
                break
            @unknown default:
                break
            }
        }
        .onDisappear {
            // 视图消失时，停止播放
            player?.pause()
            isPlaying = false
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
                            
                            // 如果是第一个视频或者当前没有加载视频，则加载它
                            if self.appState.selectedVideoURLs.count == 1 || self.player == nil {
                                self.loadVideoPlayer(from: video.url)
                            }
                        }
                    case .failure(let error):
                        print("Error loading video: \(error)")
                    }
                }
            }
        }
    }
    
    private func loadVideoPlayer(from url: URL) {
        // 先停止当前播放器
        if let currentPlayer = player {
            currentPlayer.pause()
        }
        
        player = AVPlayer(url: url)
        isPlaying = false
        currentTime = 0
        duration = 0
        
        // Set up time observer
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            self.currentTime = time.seconds
            if self.duration == 0 {
                self.duration = self.player?.currentItem?.duration.seconds ?? 0
            }
        }
        
        // Apply mute state
        player?.isMuted = appState.isMuted
    }
    
    private func loadVideo(from item: PhotosPickerItem) {
        item.loadTransferable(type: VideoTransferable.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let video):
                    if let video = video {
                        appState.selectedVideoURL = video.url
                        appState.hasImportedVideo = true
                        setupPlayer(with: video.url)
                    }
                case .failure(let error):
                    print("Error loading video: \(error)")
                }
            }
        }
    }
    
    private func setupPlayer(with url: URL) {
        // 先停止当前播放器
        if let currentPlayer = player {
            currentPlayer.pause()
        }
        
        player = AVPlayer(url: url)
        // Add observer for time updates
        if let player = player {
            let timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main) { time in
                currentTime = time.seconds
                if duration == 0 {
                    duration = player.currentItem?.duration.seconds ?? 0
                }
            }
        }
    }
}

// MARK: - Mute Video Preview View
struct MuteVideoPreviewView: View {
    @Binding var player: AVPlayer?
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 16) {
            // Video Player
            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        // Play/Pause Overlay - 完全居中
                        ZStack {
                            Button(action: togglePlayPause) {
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                        }
                    )
                    .onTapGesture {
                        togglePlayPause()
                    }
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "play.circle")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("Video Preview")
                                .foregroundColor(.gray)
                        }
                    )
            }
            
            // Timeline
            VStack(spacing: 8) {
                HStack {
                    Button(action: {
                        // Volume toggle
                        appState.isMuted.toggle()
                    }) {
                        Image(systemName: appState.isMuted ? "speaker.slash" : "speaker.wave.2")
                            .foregroundColor(.primary)
                    }
                    
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 4)
                            
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * (currentTime / max(duration, 1)), height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    Text(formatTime(currentTime) + " / " + formatTime(duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
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
    
    var body: some View {
        VStack(spacing: 16) {
            // Mute Toggle
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "speaker.slash")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mute Audio")
                        .font(.headline)
                    Text("Remove all audio from video")
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
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: {
                    // Preview
                }) {
                    HStack {
                        Image(systemName: "eye")
                        Text("Preview")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: {
                    // Save
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
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
