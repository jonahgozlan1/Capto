//
//  EmptyStateView.swift
//  Capto
//
//  Created by Refactoring on 01/27/25.
//

import SwiftUI

/// Friendly empty state that still respects the centered bubble aesthetic.
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 42))
                .foregroundStyle(Color.secondary)
            Text("Start typing to capture your first thought.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.secondary)
            Text("Thoughts will appear here as cozy bubbles.")
                .font(.callout)
                .foregroundStyle(Color.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

