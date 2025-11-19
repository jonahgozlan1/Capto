//
//  DateHeaderView.swift
//  Capto
//
//  Created by Refactoring on 01/27/25.
//

import SwiftUI

/// Stylized date header that sticks to the centered layout.
struct DateHeaderView: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title.uppercased())
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.04 : 0.10),
                                        Color.white.opacity(colorScheme == .dark ? 0.02 : 0.05)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.15),
                                Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.08)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.05),
                radius: DesignSystem.Shadow.dateHeaderRadius,
                y: DesignSystem.Shadow.dateHeaderY
            )
            .accessibilityAddTraits(.isHeader)
    }
}

