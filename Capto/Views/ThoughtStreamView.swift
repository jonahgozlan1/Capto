//
//  ThoughtStreamView.swift
//  Capto
//
//  Created by Refactoring on 01/27/25.
//

import SwiftUI

/// Displays the date-grouped stack of thought bubbles with consistent width.
struct ThoughtStreamView: View {
    let sections: [ThoughtStreamModel.ThoughtSection]
    let availableWidth: CGFloat
    let isTimestampVisible: (UUID) -> Bool
    let toggleTimestamp: (UUID) -> Void
    let revealTimestamp: (UUID) -> Void
    let requestDelete: (Thought) -> Void

    private var bubbleWidth: CGFloat {
        let target = availableWidth * DesignSystem.Bubble.widthMultiplier
        return min(max(target, DesignSystem.Bubble.minWidth), DesignSystem.Bubble.maxWidth)
    }

    var body: some View {
        ForEach(sections) { section in
            // DateHeaderView as direct child of LazyVStack
            DateHeaderView(title: section.title)
                .padding(.bottom, DesignSystem.Spacing.timestamp) // Spacing between header and thoughts
            
            // ForEach with thoughts as direct children of LazyVStack
            ForEach(section.thoughts) { bubble in
                ThoughtBubbleView(
                    thought: bubble,
                    bubbleWidth: bubbleWidth,
                    isTimestampVisible: isTimestampVisible(bubble.id),
                    toggleTimestamp: { toggleTimestamp(bubble.id) },
                    revealTimestamp: { revealTimestamp(bubble.id) },
                    requestDelete: { requestDelete(bubble) }
                )
                .id(bubble.id) // Now a direct child of LazyVStack - ScrollViewReader can find it!
                .accessibilityLabel("Thought at \(bubble.createdAt.formatted(date: .numeric, time: .shortened))")
                .accessibilityValue(bubble.content)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.92).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

