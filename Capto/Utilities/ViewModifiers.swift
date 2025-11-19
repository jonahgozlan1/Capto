//
//  ViewModifiers.swift
//  Capto
//
//  Created by Refactoring on 01/27/25.
//

import SwiftUI

/// Reusable view modifiers for consistent glass styling throughout the app.
extension View {
    /// Applies liquid glass material styling with gradient background and stroke.
    /// - Parameters:
    ///   - cornerRadius: The corner radius for the rounded rectangle
    ///   - material: The material to use (default: .ultraThinMaterial)
    ///   - strokeWidth: The width of the border stroke (default: 0.5)
    ///   - includeSpecularRim: Whether to include the specular rim highlight (default: false)
    func liquidGlassStyle(
        cornerRadius: CGFloat,
        material: Material = .ultraThinMaterial,
        strokeWidth: CGFloat = 0.5,
        includeSpecularRim: Bool = false
    ) -> some View {
        self
            .background(material)
            .background(glassGradientBackground(cornerRadius: cornerRadius))
            .overlay(glassStroke(cornerRadius: cornerRadius, strokeWidth: strokeWidth))
            .overlay(includeSpecularRim ? glassSpecularRim(cornerRadius: cornerRadius) : nil)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
    
    /// Applies liquid glass material styling for capsule shapes.
    /// - Parameters:
    ///   - material: The material to use (default: .ultraThinMaterial)
    ///   - strokeWidth: The width of the border stroke (default: 0.5)
    func liquidGlassCapsuleStyle(
        material: Material = .ultraThinMaterial,
        strokeWidth: CGFloat = 0.5
    ) -> some View {
        self
            .background(material)
            .background(glassGradientCapsuleBackground())
            .overlay(glassCapsuleStroke(strokeWidth: strokeWidth))
            .clipShape(Capsule(style: .continuous))
    }
}

// MARK: - Private Glass Styling Components

private struct GlassGradientBackground: View {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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
    }
}

private struct GlassGradientCapsuleBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
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
    }
}

private struct GlassStroke: View {
    let cornerRadius: CGFloat
    let strokeWidth: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.18),
                        Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: strokeWidth
            )
    }
}

private struct GlassCapsuleStroke: View {
    let strokeWidth: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
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
                lineWidth: strokeWidth
            )
    }
}

private struct GlassSpecularRim: View {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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

// MARK: - Helper Functions

private func glassGradientBackground(cornerRadius: CGFloat) -> some View {
    GlassGradientBackground(cornerRadius: cornerRadius)
}

private func glassGradientCapsuleBackground() -> some View {
    GlassGradientCapsuleBackground()
}

private func glassStroke(cornerRadius: CGFloat, strokeWidth: CGFloat) -> some View {
    GlassStroke(cornerRadius: cornerRadius, strokeWidth: strokeWidth)
}

private func glassCapsuleStroke(strokeWidth: CGFloat) -> some View {
    GlassCapsuleStroke(strokeWidth: strokeWidth)
}

private func glassSpecularRim(cornerRadius: CGFloat) -> some View {
    GlassSpecularRim(cornerRadius: cornerRadius)
}

