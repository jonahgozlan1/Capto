//
//  ThoughtStreamModel.swift
//  Capto
//
//  Created by Cursor GPT on 11/17/25.
//

import Foundation
import Observation
import SwiftData

/// Handles the primary data flow for the thought stream using SwiftData (B-003).
@Observable
@MainActor
final class ThoughtStreamModel {

    struct ThoughtSection: Identifiable, Equatable {
        let id: String
        let date: Date
        let title: String
        var thoughts: [Thought]
    }

    private let pageSize = 50

    /// Text inside the composer.
    var draftText: String = "" {
        didSet {
            print("[ThoughtStreamModel] Updated draft text length: \(draftText.count)")
        }
    }

    /// Backing store reflecting the persisted thoughts (chronological order).
    private(set) var thoughts: [Thought] = [] {
        didSet {
            if oldValue.count != thoughts.count {
                print("[ThoughtStreamModel] Thoughts count now: \(thoughts.count)")
            }
            rebuildSectionsCache()
        }
    }

    /// Cached sections to avoid recomputing for every render.
    private(set) var thoughtSections: [ThoughtSection] = [] {
        didSet {
            if oldValue.count != thoughtSections.count {
                print("[ThoughtStreamModel] Rebuilt sections: \(thoughtSections.count)")
            }
        }
    }

    /// Surface-level error message for user alerts.
    var sendErrorMessage: String? {
        didSet {
            if let message = sendErrorMessage {
                print("[ThoughtStreamModel] Error raised -> \(message)")
            }
        }
    }

    /// Error surfaced when deletion fails.
    var deleteErrorMessage: String? {
        didSet {
            if let message = deleteErrorMessage {
                print("[ThoughtStreamModel] Delete error -> \(message)")
            }
        }
    }

    /// Warning surfaced for blank sends and similar user errors.
    var blankSendErrorMessage: String? {
        didSet {
            if let message = blankSendErrorMessage {
                print("[ThoughtStreamModel] Blank send warning -> \(message)")
            }
        }
    }

    /// Pagination/error state for loading older thoughts.
    var loadOlderErrorMessage: String? {
        didSet {
            if let message = loadOlderErrorMessage {
                print("[ThoughtStreamModel] Load older error -> \(message)")
            }
        }
    }
    var isLoadingOlder: Bool = false {
        didSet {
            print("[ThoughtStreamModel] Loading older: \(isLoadingOlder)")
        }
    }
    var canLoadOlder: Bool = false {
        didSet {
            print("[ThoughtStreamModel] Can load older: \(canLoadOlder)")
        }
    }

    /// Search state surfaced to the UI.
    var searchQuery: String = "" {
        didSet {
            guard searchQuery != oldValue else { return }
            performSearch(for: searchQuery)
        }
    }
    var searchResults: [Thought] = [] {
        didSet {
            print("[ThoughtStreamModel] Search results count: \(searchResults.count)")
        }
    }
    var searchErrorMessage: String? {
        didSet {
            if let message = searchErrorMessage {
                print("[ThoughtStreamModel] Search error -> \(message)")
            }
        }
    }
    var isSearching: Bool = false {
        didSet {
            if isSearching {
                print("[ThoughtStreamModel] Performing search…")
            }
        }
    }

    @ObservationIgnored
    private var modelContext: ModelContext?

    @ObservationIgnored
    private let calendar = Calendar.current

    @ObservationIgnored
    private var oldestLoadedDate: Date?

    @ObservationIgnored
    private var lastSearchQuery: String = ""

    /// Injects the SwiftData context and triggers the initial load once.
    func configureContextIfNeeded(_ context: ModelContext) {
        guard modelContext !== context else { return }
        print("[ThoughtStreamModel] Received model context; loading thoughts")
        modelContext = context
        refreshThoughts()
    }

    /// Called when the main screen appears so we can ensure we have data.
    func handleAppear() {
        print("[ThoughtStreamModel] View appeared, verifying context availability")
        refreshThoughts()
    }

    /// Forces a fetch from SwiftData to keep the list in sync.
    func refreshThoughts() {
        guard let context = modelContext else {
            print("[ThoughtStreamModel] refreshThoughts called before context injection")
            return
        }

        do {
            thoughts = try fetchThoughts(limit: pageSize, before: nil, in: context)
            oldestLoadedDate = thoughts.first?.createdAt
            loadOlderErrorMessage = nil
            canLoadOlder = try checkForMoreThoughts(before: oldestLoadedDate, in: context)
            print("[ThoughtStreamModel] Refreshed thoughts from persistence")
        } catch {
            print("[ThoughtStreamModel] Failed to fetch thoughts: \(error.localizedDescription)")
            loadOlderErrorMessage = "Couldn't refresh thoughts."
        }
    }

    /// Adds the current draft as a new persisted thought.
    @discardableResult
    func sendDraft() -> Thought? {
        let trimmedText = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false else {
            print("[ThoughtStreamModel] Ignored blank draft send")
            blankSendErrorMessage = "Blank thoughts are ignored."
            return nil
        }
        guard let context = modelContext else {
            print("[ThoughtStreamModel] Cannot send draft without model context")
            return nil
        }

        let thought = Thought(content: trimmedText)
        context.insert(thought)

        do {
            try context.save()
            print("[ThoughtStreamModel] Saved new thought with id \(thought.id)")
            draftText = ""
            sendErrorMessage = nil
            blankSendErrorMessage = nil
            refreshThoughts()
            return thought
        } catch {
            context.delete(thought)
            print("[ThoughtStreamModel] Failed to save thought: \(error.localizedDescription)")
            sendErrorMessage = "Failed to save thought. Try again."
            return nil
        }
    }

    /// Clears the blank-send warning to avoid sticky alerts.
    func acknowledgeBlankSendError() {
        blankSendErrorMessage = nil
    }

    /// Clears the surfaced error so alerts can dismiss cleanly.
    func acknowledgeError() {
        sendErrorMessage = nil
    }

    /// Clears delete error state.
    func acknowledgeDeleteError() {
        deleteErrorMessage = nil
    }

    /// Permanently deletes a thought after user confirmation.
    func deleteThought(_ thought: Thought) {
        guard let context = modelContext else {
            print("[ThoughtStreamModel] Cannot delete without model context")
            deleteErrorMessage = "Unable to delete thought. Try again."
            return
        }

        context.delete(thought)
        do {
            try context.save()
            print("[ThoughtStreamModel] Deleted thought \(thought.id)")
            deleteErrorMessage = nil
            refreshThoughts()
        } catch {
            context.rollback()
            print("[ThoughtStreamModel] Failed to delete thought: \(error.localizedDescription)")
            deleteErrorMessage = "Failed to delete thought. Try again."
        }
    }

    /// Fetches the next page of older thoughts for pull-to-refresh pagination.
    func loadOlderThoughts() async {
        guard canLoadOlder, isLoadingOlder == false else {
            print("[ThoughtStreamModel] Skipping load older - canLoadOlder=\(canLoadOlder) loading=\(isLoadingOlder)")
            return
        }
        guard let context = modelContext else {
            print("[ThoughtStreamModel] Cannot load older without context")
            loadOlderErrorMessage = "Couldn't load older thoughts. Pull to try again."
            return
        }
        guard let cutoff = oldestLoadedDate else {
            print("[ThoughtStreamModel] No cutoff date; disabling pagination")
            canLoadOlder = false
            return
        }

        isLoadingOlder = true
        loadOlderErrorMessage = nil

        do {
            let olderBatch = try fetchThoughts(limit: pageSize, before: cutoff, in: context)
            if olderBatch.isEmpty {
                canLoadOlder = false
                print("[ThoughtStreamModel] No older thoughts found")
            } else {
                thoughts.insert(contentsOf: olderBatch, at: 0)
                oldestLoadedDate = thoughts.first?.createdAt
                canLoadOlder = try checkForMoreThoughts(before: oldestLoadedDate, in: context)
            }
        } catch {
            print("[ThoughtStreamModel] Failed to load older thoughts: \(error.localizedDescription)")
            loadOlderErrorMessage = "Couldn't load older thoughts. Pull to try again."
        }

        isLoadingOlder = false
    }

    /// Clears all search-related state when leaving S-002.
    func resetSearchState() {
        searchQuery = ""
        searchResults = []
        searchErrorMessage = nil
        blankSendErrorMessage = nil
        isSearching = false
        lastSearchQuery = ""
    }

    func retrySearch() {
        guard isSearching == false else {
            print("[ThoughtStreamModel] Already searching; ignoring retry")
            return
        }
        guard lastSearchQuery.isEmpty == false else {
            searchErrorMessage = "Nothing to retry."
            return
        }
        performSearch(for: lastSearchQuery, shouldStoreQuery: false)
    }

    private func performSearch(for rawQuery: String, shouldStoreQuery: Bool = true) {
        let trimmed = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let context = modelContext else {
            if trimmed.isEmpty == false {
                searchErrorMessage = "Search unavailable. Try again."
            }
            return
        }

        guard trimmed.isEmpty == false else {
            searchResults = []
            searchErrorMessage = nil
            isSearching = false
            if shouldStoreQuery {
                lastSearchQuery = ""
            }
            return
        }

        if shouldStoreQuery {
            lastSearchQuery = trimmed
        }

        isSearching = true
        searchErrorMessage = nil

        do {
            let predicate = #Predicate<Thought> { thought in
                thought.content.localizedStandardContains(trimmed)
            }
            var descriptor = FetchDescriptor<Thought>(
                predicate: predicate,
                sortBy: [SortDescriptor(\Thought.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 200
            searchResults = try context.fetch(descriptor)
        } catch {
            print("[ThoughtStreamModel] Search failed: \(error.localizedDescription)")
            searchErrorMessage = "Search failed. Try again."
            searchResults = []
        }

        isSearching = false
    }

    private func fetchThoughts(limit: Int, before cutoff: Date?, in context: ModelContext) throws -> [Thought] {
        var descriptor = FetchDescriptor<Thought>(
            sortBy: [SortDescriptor(\Thought.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        if let cutoff {
            descriptor.predicate = #Predicate<Thought> { $0.createdAt < cutoff }
        }

        let results = try context.fetch(descriptor)
        return results.reversed()
    }

    private func checkForMoreThoughts(before cutoff: Date?, in context: ModelContext) throws -> Bool {
        guard let cutoff else { return false }

        var descriptor = FetchDescriptor<Thought>(
            sortBy: [SortDescriptor(\Thought.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        descriptor.predicate = #Predicate<Thought> { $0.createdAt < cutoff }

        return try context.fetch(descriptor).isEmpty == false
    }

    private func rebuildSectionsCache() {
        thoughtSections = Self.buildSections(from: thoughts, calendar: calendar)
    }

    private static func buildSections(from thoughts: [Thought], calendar: Calendar) -> [ThoughtSection] {
        guard thoughts.isEmpty == false else { return [] }

        var sections: [ThoughtSection] = []
        for thought in thoughts {
            let day = calendar.startOfDay(for: thought.createdAt)
            if var last = sections.last, calendar.isDate(last.date, inSameDayAs: day) {
                last.thoughts.append(thought)
                sections[sections.count - 1] = last
            } else {
                let title = dateHeaderTitle(for: day, calendar: calendar)
                sections.append(
                    ThoughtSection(
                        id: day.iso8601String(),
                        date: day,
                        title: title,
                        thoughts: [thought]
                    )
                )
            }
        }
        return sections
    }

    private static func dateHeaderTitle(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) {
            return "Today"
        } else if calendar.isDateInYesterday(day) {
            return "Yesterday"
        } else if calendar.isDate(day, equalTo: Date.now, toGranularity: .year) {
            return DateFormatters.monthDayFormatter.string(from: day)
        } else {
            return DateFormatters.yearMonthDayFormatter.string(from: day)
        }
    }

    private func dateHeaderTitle(for day: Date) -> String {
        Self.dateHeaderTitle(for: day, calendar: calendar)
    }
}

private enum DateFormatters {
    static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    static let yearMonthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d, yyyy")
        return formatter
    }()

    static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter
    }()
}

private extension Date {
    func iso8601String() -> String {
        DateFormatters.iso8601Formatter.string(from: self)
    }
}

