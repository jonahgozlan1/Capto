//
//  CopyToastView.swift
//  Capto
//
//  Created by Refactoring on 01/27/25.
//

import SwiftUI

/// Toast notification confirming text was copied to clipboard.
struct CopyToastView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17, weight: .medium))
                .symbolRenderingMode(.hierarchical)
            Text("Copied")
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.toast, style: .continuous)
                .fill(.regularMaterial)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.toast, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.18),
                                    Color.white.opacity(colorScheme == .dark ? 0.04 : 0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.toast, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.22),
                            Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.18),
            radius: DesignSystem.Shadow.toastRadius,
            y: DesignSystem.Shadow.toastY
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.10),
            radius: DesignSystem.Shadow.toastRadiusSecondary,
            y: DesignSystem.Shadow.toastYSecondary
        )
    }
}

