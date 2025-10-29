//
//  ContentView.swift
//  loopVideo
//
//  Created by 狒狒 on 2025/10/19.
//

import SwiftUI
import AVKit
import PhotosUI
import Combine

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        ZStack {
            if appState.currentPage == .welcome {
                WelcomeView()
                    .environmentObject(appState)
            } else {
                MainTabView()
                    .environmentObject(appState)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.currentPage)
        .onAppear {
            // Initialize app state
            appState.currentPage = .welcome
        }
    }
}

// MARK: - App State
class AppState: ObservableObject {
    @Published var currentPage: AppPage = .welcome
    @Published var hasImportedVideo = false
    @Published var selectedVideoURL: URL?
    @Published var selectedVideoURLs: [URL] = [] // 新增：支持多个视频URL
    @Published var currentVideoIndex: Int = 0 // 新增：当前选中的视频索引
    @Published var isLooping = false
    @Published var loopCount: Int = 0
    @Published var currentLoopCount: LoopCount = .infinite
    @Published var isMuted = false
    
    // 新增：获取当前视频URL
    var currentVideoURL: URL? {
        selectedVideoURLs.indices.contains(currentVideoIndex) ? selectedVideoURLs[currentVideoIndex] : nil
    }
    
    // 新增：添加视频
    func addVideo(_ url: URL) {
        selectedVideoURLs.append(url)
        hasImportedVideo = true
        if selectedVideoURLs.count == 1 {
            currentVideoIndex = 0
        }
    }
    
    // 新增：移除视频
    func removeVideo(at index: Int) {
        guard index < selectedVideoURLs.count else { return }
        selectedVideoURLs.remove(at: index)
        
        if selectedVideoURLs.isEmpty {
            hasImportedVideo = false
            currentVideoIndex = 0
        } else {
            // 调整当前索引
            if currentVideoIndex >= selectedVideoURLs.count {
                currentVideoIndex = selectedVideoURLs.count - 1
            }
        }
    }
    
    // 新增：切换到下一个视频
    func nextVideo() {
        guard !selectedVideoURLs.isEmpty else { return }
        currentVideoIndex = (currentVideoIndex + 1) % selectedVideoURLs.count
    }
    
    // 新增：切换到上一个视频
    func previousVideo() {
        guard !selectedVideoURLs.isEmpty else { return }
        currentVideoIndex = currentVideoIndex > 0 ? currentVideoIndex - 1 : selectedVideoURLs.count - 1
    }
    
    // 新增：重置视频状态
    func resetVideos() {
        selectedVideoURLs.removeAll()
        hasImportedVideo = false
        selectedVideoURL = nil
        currentVideoIndex = 0
    }
}

enum AppPage {
    case welcome
    case main
}

enum LoopCount: String, CaseIterable {
    case one = "1"
    case three = "3"
    case infinite = "∞"
    
    var displayName: String {
        switch self {
        case .one: return "Loop 1x"
        case .three: return "Loop 3x"
        case .infinite: return "Loop ∞"
        }
    }
    
    var value: Int? {
        switch self {
        case .one: return 1
        case .three: return 3
        case .infinite: return nil
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Status bar spacer
            Color.clear.frame(height: 44)
            
            VStack(spacing: 40) {
                // App Title
                VStack(spacing: 8) {
                    Text("Smooth Loop")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Create amazing video loops easily")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // App Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 96, height: 96)
                    
                    Image(systemName: "film")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }
                
                // Use Cases
                VStack(alignment: .leading, spacing: 16) {
                    Text("Perfect for:")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        UseCaseCard(icon: "bag", title: "Store Displays")
                        UseCaseCard(icon: "iphone", title: "Social Media")
                        UseCaseCard(icon: "antenna.radiowaves.left.and.right", title: "Digital Signage")
                        UseCaseCard(icon: "megaphone", title: "Advertising")
                    }
                }
                .frame(maxWidth: 300)
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: {
                        appState.currentPage = .main
                    }) {
                        HStack {
                            Image(systemName: "arrow.right")
                            Text("Start Using")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, Color.blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        // Show how it works
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("How It Works")
                        }
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 40)
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
}

struct UseCaseCard: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LoopCreatorView()
                .tabItem {
                    Image(systemName: "repeat")
                    Text("Loop")
                }
                .tag(0)
            
            MuteToolView()
                .tabItem {
                    Image(systemName: "speaker.slash")
                    Text("Mute")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

#Preview {
    ContentView()
}
