//
//  ErrorBanners.swift
//  Capto
//
//  Created by Refactoring on 01/27/25.
//

import SwiftUI

/// Banner surfaced when pagination fails.
struct LoadErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.errorBanner, style: .continuous)
                    .fill(Color.red.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.errorBanner, style: .continuous)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
            .accessibilityLabel("Pagination error")
            .accessibilityValue(message)
            .padding(.bottom, 12)
    }
}

/// Toast-style banner if a background search fails.
struct SearchErrorBanner: View {
    let message: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.yellow, Color.yellow.opacity(0.6))
            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.errorBanner, style: .continuous)
                .fill(Color.yellow.opacity(colorScheme == .dark ? 0.25 : 0.15))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.6 : 0.15), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.errorBanner, style: .continuous)
                .stroke(Color.yellow.opacity(0.35), lineWidth: 1)
        )
        .padding(.bottom, 12)
        .accessibilityLabel("Search error")
        .accessibilityValue(message)
    }
}

