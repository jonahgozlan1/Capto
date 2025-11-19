//
//  SearchView.swift
//  Capto
//
//  Created by Refactoring on 01/27/25.
//

import SwiftUI

/// Full-screen search experience.
struct SearchView: View {
    @Bindable var model: ThoughtStreamModel
    let dismissAction: () -> Void

    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                Divider()
                    .opacity(0.15)
                searchResultsContent
            }
            .background(.ultraThinMaterial)
            .ignoresSafeArea()
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + DesignSystem.ScrollTiming.searchFocusDelay) {
                    isSearchFieldFocused = true
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 17, weight: .medium))
                TextField("Search thoughts", text: $model.searchQuery)
                    .focused($isSearchFieldFocused)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                if model.isSearching {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.9)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.searchBar, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.searchBar, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.04),
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.searchBar, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.primary.opacity(0.12),
                                Color.primary.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: Color.black.opacity(0.08),
                radius: DesignSystem.Shadow.searchBarRadius,
                y: DesignSystem.Shadow.searchBarY
            )

            Button("Cancel") {
                dismissAction()
            }
            .foregroundStyle(Color.accentColor)
            .fontWeight(.semibold)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.04),
                        Color.white.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
        )
        .shadow(
            color: Color.black.opacity(0.06),
            radius: 12,
            y: 4
        )
    }

    private var searchResultsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if trimmedQuery.isEmpty {
                    SearchHintView()
                } else if let error = model.searchErrorMessage {
                    SearchErrorView(message: error) {
                        model.retrySearch()
                    }
                } else if model.isSearching {
                    SearchLoadingView()
                } else if model.searchResults.isEmpty {
                    SearchNoResultsView(query: trimmedQuery)
                } else {
                    LazyVStack(spacing: 16, pinnedViews: []) {
                        ForEach(model.searchResults) { thought in
                            SearchResultRow(
                                highlightedText: highlightedText(for: thought.content, query: trimmedQuery),
                                timestamp: thought.createdAt
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
    }

    private var trimmedQuery: String {
        model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SearchResultRow: View {
    let highlightedText: Text
    let timestamp: Date
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            highlightedText
                .font(.body)
                .multilineTextAlignment(.leading)
            Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.04 : 0.10),
                                    Color.white.opacity(colorScheme == .dark ? 0.02 : 0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.15),
                            Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.20 : 0.06),
            radius: 16,
            y: 4
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.10 : 0.03),
            radius: 32,
            y: 8
        )
        .accessibilityElement(children: .combine)
    }
}

private struct SearchHintView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text("Search your entire thought history.")
                .font(.headline)
            Text("Type a keyword to jump back to any idea instantly.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}

private struct SearchLoadingView: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Searching…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

private struct SearchNoResultsView: View {
    let query: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.bubble")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No thoughts found for \"\(query)\"")
                .font(.headline)
            Text("Try another word or check your spelling.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

private struct SearchErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.leading)
            }

            Button(action: retryAction) {
                Text("Try Again")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.errorBanner, style: .continuous)
                            .fill(Color.accentColor.opacity(0.15))
                    )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.yellow.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
        .padding(.vertical, 40)
    }
}

private func highlightedText(for text: String, query: String) -> Text {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedQuery.isEmpty == false else {
        return Text(text)
    }

    var attributed = AttributedString(text)
    var searchRange = text.startIndex..<text.endIndex

    while let range = text.range(
        of: trimmedQuery,
        options: [.caseInsensitive, .diacriticInsensitive],
        range: searchRange,
        locale: .current
    ) {
        if let lower = AttributedString.Index(range.lowerBound, within: attributed),
           let upper = AttributedString.Index(range.upperBound, within: attributed) {
            attributed[lower..<upper].foregroundColor = colorSchemeAccentedColor()
            attributed[lower..<upper].font = .body.weight(.semibold)
        }
        searchRange = range.upperBound..<text.endIndex
    }

    return Text(attributed)
}

private func colorSchemeAccentedColor() -> Color {
    #if os(iOS)
    return Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? UIColor.systemTeal : UIColor.systemBlue
    })
    #else
    return Color.accentColor
    #endif
}

