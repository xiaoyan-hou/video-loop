//
//  SettingsView.swift
//  loopVideo
//
//  Created by 狒狒 on 2025/10/19.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                // Settings List
                VStack(spacing: 0) {
                    SettingsRow(
                        icon: "star",
                        title: "Rate App",
                        action: {
                            // Rate app action
                        }
                    )
                    
                    SettingsRow(
                        icon: "square.and.arrow.up",
                        title: "Share App",
                        action: {
                            // Share app action
                        }
                    )
                    
                    SettingsRow(
                        icon: "lock",
                        title: "Privacy Policy",
                        action: {
                            if let url = URL(string: "https://www.freeprivacypolicy.com/live/94b210b2-9fc4-4ef3-839e-e5feb999e71e") {
                                openURL(url)
                            }
                        }
                    )
                    
                    SettingsRow(
                        icon: "doc.text",
                        title: "Terms of Use",
                        action: {
                            if let url = URL(string: "https://www.freeprivacypolicy.com/live/ccb25690-1345-4964-878e-fb249129cc92") {
                                openURL(url)
                            }
                        }
                    )
                    
                    SettingsRow(
                        icon: "envelope",
                        title: "Contact Us",
                        action: {
                            // Contact us action
                        }
                    )
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // App Info
                VStack(spacing: 4) {
                    Text("Smooth Loop")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Version 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 40)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                
                // Title
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
