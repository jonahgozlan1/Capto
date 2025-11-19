//
//  ThoughtBubbleView.swift
//  Capto
//
//  Created by Refactoring on 01/27/25.
//

import SwiftUI
import UIKit

/// Thought bubble styling that mirrors iOS-native message visuals.
struct ThoughtBubbleView: View {
    let thought: Thought
    let bubbleWidth: CGFloat
    let isTimestampVisible: Bool
    let toggleTimestamp: () -> Void
    let revealTimestamp: () -> Void
    let requestDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var showShareSheet = false
    @State private var showCopyToast = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.timestamp) {
            Text(thought.content)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.leading)
                .frame(width: bubbleWidth, alignment: .leading)
                .padding(.vertical, DesignSystem.Bubble.paddingVertical)
                .padding(.horizontal, DesignSystem.Bubble.paddingHorizontal)
                .background(bubbleBackground)
                .overlay(bubbleStroke)
                .overlay(bubbleSpecularRim)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.bubble, style: .continuous))
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08),
                    radius: DesignSystem.Shadow.bubbleRadius,
                    y: DesignSystem.Shadow.bubbleY
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.1 : 0.03),
                    radius: DesignSystem.Shadow.bubbleRadiusSecondary,
                    y: DesignSystem.Shadow.bubbleYSecondary
                )
                .contentShape(Rectangle())
                .contextMenu {
                    Button(action: {
                        copyToClipboard()
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    
                    Button(action: {
                        showShareSheet = true
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(role: .destructive, action: {
                        requestDelete()
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .onTapGesture {
                    if isTimestampVisible {
                        // If timestamp is visible, tap hides it
                        logDebug("[ThoughtBubbleView] Tap detected, hiding timestamp for \(thought.id)")
                        toggleTimestamp()
                    } else {
                        // Otherwise, tap toggles timestamp
                        logDebug("[ThoughtBubbleView] Tap toggled timestamp for \(thought.id)")
                        toggleTimestamp()
                    }
                }
                .sheet(isPresented: $showShareSheet) {
                    ShareSheet(activityItems: [thought.content])
                }

            Text(thought.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
                .opacity(isTimestampVisible ? 1 : 0)
                .animation(.easeInOut(duration: DesignSystem.Animation.timestampDuration), value: isTimestampVisible)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .center) {
            if showCopyToast {
                CopyToastView()
                    .transition(.opacity.combined(with: .scale))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + DesignSystem.ScrollTiming.copyToastDuration) {
                            withAnimation {
                                showCopyToast = false
                            }
                        }
                    }
            }
        }
    }
    
    /// Copies thought content to clipboard and shows confirmation toast.
    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = thought.content
        logDebug("[ThoughtBubbleView] Copied thought \(thought.id) to clipboard")
        withAnimation {
            showCopyToast = true
        }
        #endif
    }

    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.bubble, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                // Additional depth layer for liquid glass effect
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.bubble, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.15),
                                Color.white.opacity(colorScheme == .dark ? 0.02 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }

    private var bubbleStroke: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.bubble, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.18),
                        Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
    }
    
    /// Specular rim highlight for liquid glass effect (iOS 26 style).
    private var bubbleSpecularRim: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.bubble, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.15 : 0.25),
                        Color.clear,
                        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
            .blendMode(.overlay)
            .opacity(0.6)
    }
}

