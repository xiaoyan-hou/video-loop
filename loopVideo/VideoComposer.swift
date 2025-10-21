//
//  VideoComposer.swift
//  loopVideo
//
//  视频合成和导出功能
//

import Foundation
import AVFoundation
import UIKit
import Photos
import Combine

class VideoComposer: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var statusMessage = ""
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    // 合并多个视频
    func combineVideos(urls: [URL], completion: @escaping (Result<URL, Error>) -> Void) {
        guard !urls.isEmpty else {
            completion(.failure(VideoComposerError.noVideos))
            return
        }
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.progress = 0.0
            self.statusMessage = "Preparing videos..."
        }
        
        // 在后台线程执行视频合并
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let composition = AVMutableComposition()
                
                guard let videoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    throw VideoComposerError.compositionFailed
                }
                
                guard let audioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    throw VideoComposerError.compositionFailed
                }
                
                var currentTime = CMTime.zero
                let totalVideos = urls.count
                
                // 依次添加每个视频
                for (index, url) in urls.enumerated() {
                    let asset = AVAsset(url: url)
                    
                    DispatchQueue.main.async {
                        self.progress = Double(index) / Double(totalVideos) * 0.5
                        self.statusMessage = "Processing video \(index + 1) of \(totalVideos)..."
                    }
                    
                    // 获取视频轨道
                    guard let assetVideoTrack = asset.tracks(withMediaType: .video).first else {
                        continue
                    }
                    
                    let duration = asset.duration
                    let timeRange = CMTimeRange(start: .zero, duration: duration)
                    
                    // 添加视频轨道
                    try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
                    
                    // 添加音频轨道（如果存在）
                    if let assetAudioTrack = asset.tracks(withMediaType: .audio).first {
                        try audioTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: currentTime)
                    }
                    
                    // 保持视频方向
                    videoTrack.preferredTransform = assetVideoTrack.preferredTransform
                    
                    currentTime = CMTimeAdd(currentTime, duration)
                }
                
                DispatchQueue.main.async {
                    self.statusMessage = "Exporting combined video..."
                    self.progress = 0.5
                }
                
                // 导出合并后的视频
                let outputURL = self.getTemporaryOutputURL()
                
                guard let exportSession = AVAssetExportSession(
                    asset: composition,
                    presetName: AVAssetExportPresetHighestQuality
                ) else {
                    throw VideoComposerError.exportFailed
                }
                
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mp4
                exportSession.shouldOptimizeForNetworkUse = true
                
                // 监控导出进度 - 必须在主线程创建 Timer
                var timer: Timer?
                DispatchQueue.main.async {
                    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                        DispatchQueue.main.async {
                            self.progress = 0.5 + Double(exportSession.progress) * 0.5
                        }
                    }
                }
                
                exportSession.exportAsynchronously {
                    // 停止 timer - 必须在主线程
                    DispatchQueue.main.async {
                        timer?.invalidate()
                        self.isProcessing = false
                        self.progress = 1.0
                    }
                    
                    switch exportSession.status {
                    case .completed:
                        DispatchQueue.main.async {
                            self.statusMessage = "Video combined successfully!"
                        }
                        completion(.success(outputURL))
                        
                    case .failed:
                        if let error = exportSession.error {
                            completion(.failure(error))
                        } else {
                            completion(.failure(VideoComposerError.exportFailed))
                        }
                        
                    case .cancelled:
                        completion(.failure(VideoComposerError.cancelled))
                        
                    default:
                        completion(.failure(VideoComposerError.unknown))
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.progress = 0.0
                    self.statusMessage = ""
                }
                completion(.failure(error))
            }
        }
    }
    
    // 保存视频到相册
    func saveToPhotos(videoURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        // 检查相册访问权限 - 使用 .addOnly 权限
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                self.performSave(videoURL: videoURL, status: status, completion: completion)
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                self.performSave(videoURL: videoURL, status: status, completion: completion)
            }
        }
    }
    
    private func performSave(videoURL: URL, status: PHAuthorizationStatus, completion: @escaping (Result<Void, Error>) -> Void) {
        guard status == .authorized || status == .limited else {
            DispatchQueue.main.async {
                completion(.failure(VideoComposerError.photoLibraryPermissionDenied))
            }
            return
        }
        
        // 保存视频
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.failure(VideoComposerError.saveFailed))
                }
            }
        }
    }
    
    // 获取临时输出文件URL
    private func getTemporaryOutputURL() -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "combined_video_\(UUID().uuidString).mp4"
        return tempDirectory.appendingPathComponent(fileName)
    }
    
    // 显示成功提示
    func showSuccess(message: String) {
        alertTitle = "Success"
        alertMessage = message
        showAlert = true
    }
    
    // 显示错误提示
    func showError(_ error: Error) {
        alertTitle = "Error"
        alertMessage = error.localizedDescription
        showAlert = true
    }
}

// 视频合成错误类型
enum VideoComposerError: LocalizedError {
    case noVideos
    case compositionFailed
    case exportFailed
    case cancelled
    case saveFailed
    case photoLibraryPermissionDenied
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .noVideos:
            return "No videos selected to combine"
        case .compositionFailed:
            return "Failed to create video composition"
        case .exportFailed:
            return "Failed to export combined video"
        case .cancelled:
            return "Export was cancelled"
        case .saveFailed:
            return "Failed to save video"
        case .photoLibraryPermissionDenied:
            return "Photo library access denied. Please enable it in Settings."
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

