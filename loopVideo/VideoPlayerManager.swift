//
//  VideoPlayerManager.swift
//  loopVideo
//
//  Created by 狒狒 on 2025/10/19.
//

import Foundation
import AVKit
import Combine

class VideoPlayerManager: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isLooping = false
    @Published var loopCount: Int = 0
    @Published var currentLoopCount: LoopCount = .infinite
    @Published var selectedVideoURLs: [URL] = []
    @Published var currentVideoIndex: Int = 0
    
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupObservers()
    }
    
    deinit {
        removeTimeObserver()
        removeEndObserver()
    }
    
    private func setupObservers() {
        // Observe player changes
        $player
            .sink { [weak self] player in
                self?.removeTimeObserver()
                self?.removeEndObserver()
                if let player = player {
                    self?.addTimeObserver(to: player)
                    self?.addEndObserver(to: player)
                }
            }
            .store(in: &cancellables)
    }
    
    func loadVideo(from url: URL) {
        // 如果已有播放器，替换 currentItem 而不是创建新播放器
        if let currentPlayer = player {
            currentPlayer.pause()
            // 移除旧的结束通知观察者
            removeEndObserver()
            let newItem = AVPlayerItem(url: url)
            currentPlayer.replaceCurrentItem(with: newItem)
            // 为新的 item 添加结束通知观察者
            addEndObserver(to: currentPlayer)
        } else {
            // 首次加载时创建新播放器
            player = AVPlayer(url: url)
        }
        
        isPlaying = false
        currentTime = 0
        duration = 0
        // 注意：不要在这里重置 loopCount，因为这会影响多视频循环计数
    }
    
    func play() {
        guard let player = player else { return }
        player.play()
        isPlaying = true
    }
    
    func pause() {
        guard let player = player else { return }
        player.pause()
        isPlaying = false
    }
    
    func stop() {
        guard let player = player else { return }
        player.pause()
        player.seek(to: .zero)
        isPlaying = false
        currentTime = 0
        loopCount = 0
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
    }
    
    func setLoopCount(_ count: LoopCount) {
        currentLoopCount = count
        loopCount = 0
    }
    
    func startLooping() {
        isLooping = true
        loopCount = 0
        play()
    }
    
    func startLoopingSelectedVideos(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        
        selectedVideoURLs = urls
        currentVideoIndex = 0
        isLooping = true
        loopCount = 0
        
        // 加载第一个视频
        loadVideo(from: urls[0])
        play()
    }
    
    func stopLooping() {
        isLooping = false
        loopCount = 0
        pause()
    }
    
    private func addTimeObserver(to player: AVPlayer) {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // 安全地更新当前时间
            let timeValue = time.seconds
            if timeValue.isFinite && !timeValue.isNaN {
                self?.currentTime = timeValue
            }
            
            // 安全地更新时长
            if self?.duration == 0 {
                if let durationValue = player.currentItem?.duration.seconds,
                   durationValue.isFinite && !durationValue.isNaN {
                    self?.duration = durationValue
                }
            }
        }
    }
    
    private func removeTimeObserver() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }
    
    private func addEndObserver(to player: AVPlayer) {
        // 监听视频播放结束
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
    }
    
    private func removeEndObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }
    
    @objc private func playerDidFinishPlaying() {
        handleVideoEnd()
    }
    
    func handleVideoEnd() {
        guard isLooping else { return }
        
        // 如果有多个选中的视频，播放下一个
        if selectedVideoURLs.count > 1 {
            currentVideoIndex += 1
            if currentVideoIndex < selectedVideoURLs.count {
                // 播放下一个视频
                loadVideo(from: selectedVideoURLs[currentVideoIndex])
                play()
                return
            } else {
                // 所有视频播放完毕，根据循环设置决定是否重新开始
                if currentLoopCount == .infinite {
                    // 无限循环，重新开始
                    currentVideoIndex = 0
                    loadVideo(from: selectedVideoURLs[0])
                    play()
                } else if let maxLoops = currentLoopCount.value {
                    // 有限循环
                    loopCount += 1
                    if loopCount < maxLoops {
                        currentVideoIndex = 0
                        loadVideo(from: selectedVideoURLs[0])
                        play()
                    } else {
                        stopLooping()
                    }
                } else {
                    stopLooping()
                }
                return
            }
        }
        
        // 单个视频的循环逻辑
        if currentLoopCount == .infinite {
            // Infinite loop
            player?.seek(to: .zero)
            play()
        } else if let maxLoops = currentLoopCount.value {
            // 增加已完成的播放次数
            loopCount += 1
            
            // 如果已完成的播放次数小于目标次数，继续播放
            if loopCount < maxLoops {
                player?.seek(to: .zero)
                play()
            } else {
                // 达到目标次数，停止循环
                stopLooping()
            }
        }
    }
    
    func formatTime(_ seconds: Double) -> String {
        // 检查是否为有效数字
        guard seconds.isFinite && !seconds.isNaN else {
            return "0:00"
        }
        
        let totalSeconds = max(0, Int(seconds))
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
