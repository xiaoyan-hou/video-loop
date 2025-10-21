//
//  VideoLibraryView.swift
//  loopVideo
//
//  Created by 狒狒 on 2025/10/19.
//
//  精确还原 add-video.jpg 设计稿

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct VideoLibraryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var selectedVideos: [PhotosPickerItem] = []
    
    // 示例视频数据
    private let videoItems = [
        VideoLibraryItem(id: "video-7823", name: "Video-7823", duration: "00:08", thumbnailName: nil),
        VideoLibraryItem(id: "video-4217", name: "Video-4217", duration: "00:03", thumbnailName: nil)
    ]
    
    var body: some View {
        ZStack {
            // 主背景色 - 深灰
            Color(red: 58/255, green: 58/255, blue: 60/255)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - 顶部区域
                topHeaderSection
                    .padding(.top, 8)
                
                // MARK: - 主内容区域
                ScrollView {
                    VStack(spacing: 0) {
                        // 标题和排序
                        titleSection
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 16)
                        
                        // 视频网格
                        videoGridSection
                            .padding(.horizontal, 16)
                    }
                }
                
                Spacer()
                
                // MARK: - 底部区域
                bottomSection
            }
        }
        .navigationBarHidden(true)
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedVideos, matching: .videos, preferredItemEncoding: .automatic, photoLibrary: .shared())
        .onChange(of: selectedVideos) { newValue in
            if !newValue.isEmpty {
                // 导入所有选中的视频
                loadVideos(from: newValue)
                // 清空选择
                selectedVideos.removeAll()
                // 导入完成后关闭视图
                dismiss()
            }
        }
    }
    
    // MARK: - 加载视频
    private func loadVideos(from items: [PhotosPickerItem]) {
        for item in items {
            item.loadTransferable(type: VideoTransferable.self) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let video):
                        if let video = video {
                            // 添加视频到AppState
                            self.appState.addVideo(video.url)
                        }
                    case .failure(let error):
                        print("Error loading video: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - 顶部 Header
    private var topHeaderSection: some View {
        HStack(spacing: 0) {
            // 左侧橙色按钮组
            HStack(spacing: 12) {
                Button(action: {}) {
                    Text("Get Loopdeck")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 28/255, green: 28/255, blue: 30/255))
                        .frame(height: 36)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 255/255, green: 149/255, blue: 0/255))
                        )
                }
                
                Button(action: {}) {
                    Text("Buy Pro")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 28/255, green: 28/255, blue: 30/255))
                        .frame(height: 36)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 255/255, green: 149/255, blue: 0/255))
                        )
                }
            }
            
            Spacer()
            
            // 右侧控制组
            VStack(alignment: .trailing, spacing: 10) {
                // Ideas 图标和设置图标
                HStack(spacing: 20) {
                    Button(action: {}) {
                        VStack(spacing: 2) {
                            Image(systemName: "lightbulb")
                                .font(.system(size: 20))
                                .foregroundColor(Color(red: 90/255, green: 200/255, blue: 250/255))
                            Text("Ideas")
                                .font(.system(size: 11))
                                .foregroundColor(Color(red: 90/255, green: 200/255, blue: 250/255))
                        }
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(red: 90/255, green: 200/255, blue: 250/255))
                    }
                }
                
                // Play All 按钮
                Button(action: {}) {
                    Text("Play All")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .frame(height: 28)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(red: 90/255, green: 200/255, blue: 250/255))
                        )
                }
                
                // Sort by Recent 文本
                Text("Sort by Recent")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - 标题区域
    private var titleSection: some View {
        HStack {
            Text("Recent Videos:")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
        }
    }
    
    // MARK: - 视频网格
    private var videoGridSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            ForEach(videoItems) { video in
                VideoThumbnailCard(video: video) {
                    // 选择视频
                    selectVideo(video)
                }
            }
        }
    }
    
    // MARK: - 底部区域
    private var bottomSection: some View {
        VStack(spacing: 0) {
            
            // Help 和 Add Videos 按钮
            HStack(spacing: 60) {
                Button(action: {}) {
                    VStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 26))
                            .foregroundColor(Color(red: 90/255, green: 200/255, blue: 250/255))
                        Text("Help")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 90/255, green: 200/255, blue: 250/255))
                    }
                }
                
                Button(action: {
                    showingImagePicker = true
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 26))
                            .foregroundColor(Color(red: 90/255, green: 200/255, blue: 250/255))
                        Text("Add Videos")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 90/255, green: 200/255, blue: 250/255))
                    }
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            
            // Home indicator spacer
            Color.clear
                .frame(height: 34)
        }
    }
 
    // MARK: - 选择视频
    private func selectVideo(_ video: VideoLibraryItem) {
        // 为示例视频创建一个临时URL（在实际应用中，应该从真实文件系统加载）
        // 这里我们使用UUID作为文件名
        let tempVideoURL = URL(fileURLWithPath: NSTemporaryDirectory() + "\(UUID().uuidString).mp4")
        
        // 添加视频到AppState
        appState.addVideo(tempVideoURL)
        dismiss()
    }
}

// MARK: - 视频库项目模型
struct VideoLibraryItem: Identifiable {
    let id: String
    let name: String
    let duration: String
    let thumbnailName: String?
}

// MARK: - 视频缩略图卡片
struct VideoThumbnailCard: View {
    let video: VideoLibraryItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // 缩略图区域
                ZStack(alignment: .topLeading) {
                    // 背景图片占位
                    Rectangle()
                        .fill(Color(red: 142/255, green: 142/255, blue: 147/255))
                        .aspectRatio(16/9, contentMode: .fit)
                    
                    // 视频名称标签
                    Text(video.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.black.opacity(0.6))
                        )
                        .padding(8)
                    
                    // 播放图标（居中）
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .cornerRadius(8)
                
                // 时长标签
                HStack {
                    Text(video.duration)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 72/255, green: 72/255, blue: 74/255))
                .cornerRadius(bottomLeading: 8, bottomTrailing: 8)
            }
            .background(Color(red: 72/255, green: 72/255, blue: 74/255))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - 自定义圆角扩展
extension View {
    func cornerRadius(bottomLeading: CGFloat, bottomTrailing: CGFloat) -> some View {
        clipShape(RoundedCorner(bottomLeading: bottomLeading, bottomTrailing: bottomTrailing))
    }
}

struct RoundedCorner: Shape {
    var bottomLeading: CGFloat = 0.0
    var bottomTrailing: CGFloat = 0.0
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - bottomTrailing))
        path.addArc(center: CGPoint(x: rect.width - bottomTrailing, y: rect.height - bottomTrailing),
                    radius: bottomTrailing,
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: 90),
                    clockwise: false)
        path.addLine(to: CGPoint(x: bottomLeading, y: rect.height))
        path.addArc(center: CGPoint(x: bottomLeading, y: rect.height - bottomLeading),
                    radius: bottomLeading,
                    startAngle: Angle(degrees: 90),
                    endAngle: Angle(degrees: 180),
                    clockwise: false)
        path.closeSubpath()
        
        return path
    }
}

// MARK: - 按钮缩放样式
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    VideoLibraryView()
        .environmentObject(AppState())
}

