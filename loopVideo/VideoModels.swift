//
//  VideoModels.swift
//  loopVideo
//
//  Created by 狒狒 on 2025/10/19.
//
//  共享的视频相关模型和结构

import Foundation
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Video Transferable
struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = URL.documentsDirectory.appending(path: "video_\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return VideoTransferable(url: copy)
        }
    }
}

