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
    
    /// Indicates when thread is switching (B-032).
    var isSwitchingThread: Bool = false {
        didSet {
            if isSwitchingThread {
                print("[ThoughtStreamModel] Thread switching started (B-032)")
            } else {
                print("[ThoughtStreamModel] Thread switching completed (B-032)")
            }
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
    
    /// Error surfaced when thread creation fails (B-022).
    var createThreadErrorMessage: String? {
        didSet {
            if let message = createThreadErrorMessage {
                print("[ThoughtStreamModel] Create thread error -> \(message)")
            }
        }
    }
    
    /// Error surfaced when thread rename fails (B-026).
    var renameThreadErrorMessage: String? {
        didSet {
            if let message = renameThreadErrorMessage {
                print("[ThoughtStreamModel] Rename thread error -> \(message)")
            }
        }
    }
    
    /// Error surfaced when thread deletion fails (B-027).
    var deleteThreadErrorMessage: String? {
        didSet {
            if let message = deleteThreadErrorMessage {
                print("[ThoughtStreamModel] Delete thread error -> \(message)")
            }
        }
    }
    
    /// Error surfaced when thread reordering fails (B-028).
    var reorderThreadErrorMessage: String? {
        didSet {
            if let message = reorderThreadErrorMessage {
                print("[ThoughtStreamModel] Reorder thread error -> \(message)")
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
    
    /// Thread list for thread list screen (B-020).
    private(set) var threads: [Thread] = [] {
        didSet {
            print("[ThoughtStreamModel] Threads count: \(threads.count)")
        }
    }
    
    /// Currently active thread (B-023).
    private(set) var currentThread: Thread? {
        didSet {
            if let thread = currentThread {
                print("[ThoughtStreamModel] Current thread changed to: \(thread.name) (B-023)")
            } else {
                print("[ThoughtStreamModel] Current thread cleared (B-023)")
            }
        }
    }
    
    /// Error surfaced when thread switching fails (B-023).
    var switchThreadErrorMessage: String? {
        didSet {
            if let message = switchThreadErrorMessage {
                print("[ThoughtStreamModel] Switch thread error -> \(message)")
            }
        }
    }

    /// Injects the SwiftData context and triggers the initial load once.
    /// Always sets the default "Thoughts" thread on app launch (B-025).
    func configureContextIfNeeded(_ context: ModelContext) {
        guard modelContext !== context else { return }
        print("[ThoughtStreamModel] Received model context; loading thoughts")
        modelContext = context
        
        // Always set default thread on app launch, regardless of previous state (B-025)
        setDefaultThreadAsCurrent()
        
        refreshThoughts()
    }
    
    /// Sets the default "Thoughts" thread as the current thread (B-023, B-025).
    /// Called on every app launch to ensure app always opens to "Thoughts" thread.
    private func setDefaultThreadAsCurrent() {
        guard let context = modelContext else {
            print("[ThoughtStreamModel] Cannot set default thread without context")
            return
        }
        
        do {
            let predicate = #Predicate<Thread> { thread in
                thread.isDefault == true
            }
            let descriptor = FetchDescriptor<Thread>(predicate: predicate)
            let defaultThreads = try context.fetch(descriptor)
            if let defaultThread = defaultThreads.first {
                currentThread = defaultThread
                print("[ThoughtStreamModel] Set default thread as current on app launch (B-025)")
            } else {
                print("[ThoughtStreamModel] Warning: Default thread not found")
            }
        } catch {
            print("[ThoughtStreamModel] Failed to fetch default thread: \(error.localizedDescription)")
        }
    }

    /// Called when the main screen appears so we can ensure we have data.
    func handleAppear() {
        print("[ThoughtStreamModel] View appeared, verifying context availability")
        refreshThoughts()
    }

    /// Forces a fetch from SwiftData to keep the list in sync (B-023: filters by current thread).
    func refreshThoughts() {
        guard let context = modelContext else {
            print("[ThoughtStreamModel] refreshThoughts called before context injection")
            return
        }
        
        // Ensure we have a current thread (B-023, B-025)
        // Note: configureContextIfNeeded should have already set it, but this is a safety check
        if currentThread == nil {
            setDefaultThreadAsCurrent()
        }
        
        guard let thread = currentThread else {
            print("[ThoughtStreamModel] Cannot refresh thoughts without current thread")
            return
        }

        do {
            thoughts = try fetchThoughts(limit: pageSize, before: nil, for: thread, in: context)
            oldestLoadedDate = thoughts.first?.createdAt
            loadOlderErrorMessage = nil
            canLoadOlder = try checkForMoreThoughts(before: oldestLoadedDate, for: thread, in: context)
            print("[ThoughtStreamModel] Refreshed thoughts from persistence for thread '\(thread.name)' (B-023)")
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

        // Ensure we have a current thread (B-023, B-024)
        if currentThread == nil {
            setDefaultThreadAsCurrent()
        }
        
        guard let thread = currentThread else {
            print("[ThoughtStreamModel] Cannot find current thread")
            sendErrorMessage = "Failed to save thought. Try again."
            return nil
        }

        // Save thought to the currently active thread (B-024)
        let thought = Thought(content: trimmedText, thread: thread)
        context.insert(thought)

        do {
            try context.save()
            print("[ThoughtStreamModel] Saved new thought with id \(thought.id) to thread '\(thread.name)' (B-024)")
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
    
    /// Fetches the default "Thoughts" thread from SwiftData (B-018).
    private func getDefaultThread(in context: ModelContext) -> Thread? {
        do {
            let predicate = #Predicate<Thread> { thread in
                thread.isDefault == true
            }
            let descriptor = FetchDescriptor<Thread>(predicate: predicate)
            let threads = try context.fetch(descriptor)
            return threads.first
        } catch {
            print("[ThoughtStreamModel] Failed to fetch default thread: \(error.localizedDescription)")
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

        guard let thread = currentThread else {
            print("[ThoughtStreamModel] Cannot load older thoughts without current thread")
            loadOlderErrorMessage = "Couldn't load older thoughts. Pull to try again."
            isLoadingOlder = false
            return
        }
        
        do {
            let olderBatch = try fetchThoughts(limit: pageSize, before: cutoff, for: thread, in: context)
            if olderBatch.isEmpty {
                canLoadOlder = false
                print("[ThoughtStreamModel] No older thoughts found")
            } else {
                thoughts.insert(contentsOf: olderBatch, at: 0)
                oldestLoadedDate = thoughts.first?.createdAt
                canLoadOlder = try checkForMoreThoughts(before: oldestLoadedDate, for: thread, in: context)
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
            // Search across all threads (B-029) - no thread filter in predicate
            let predicate = #Predicate<Thought> { thought in
                thought.content.localizedStandardContains(trimmed)
            }
            var descriptor = FetchDescriptor<Thought>(
                predicate: predicate,
                sortBy: [SortDescriptor(\Thought.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 200
            // Search across all threads (B-029) - no thread filter, relationships auto-fetched
            searchResults = try context.fetch(descriptor)
            print("[ThoughtStreamModel] Search found \(searchResults.count) results across all threads (B-029)")
        } catch {
            print("[ThoughtStreamModel] Search failed: \(error.localizedDescription)")
            searchErrorMessage = "Search failed. Try again."
            searchResults = []
        }

        isSearching = false
    }

    /// Efficiently fetches thoughts for a thread using the relationship (B-023, B-032).
    /// Uses thread.thoughts directly for optimal performance - no SwiftData query needed.
    private func fetchThoughts(limit: Int, before cutoff: Date?, for thread: Thread, in context: ModelContext) throws -> [Thought] {
        // Use the thread's thoughts relationship directly for efficient filtering (B-023, B-032)
        // This is the most efficient approach - relationship is already loaded, no query needed
        let allThreadThoughts = thread.thoughts.sorted { $0.createdAt > $1.createdAt }
        
        var filteredThoughts = allThreadThoughts
        
        // Apply date cutoff if provided (for pagination)
        if let cutoff {
            filteredThoughts = allThreadThoughts.filter { $0.createdAt < cutoff }
        }
        
        // Apply limit for pagination (B-032)
        let limitedThoughts = Array(filteredThoughts.prefix(limit))
        
        // Return in chronological order (oldest to newest) for display
        return limitedThoughts.reversed()
    }

    private func checkForMoreThoughts(before cutoff: Date?, for thread: Thread, in context: ModelContext) throws -> Bool {
        guard let cutoff else { return false }
        
        // Use the thread's thoughts relationship directly (B-023)
        let allThreadThoughts = thread.thoughts
        return allThreadThoughts.contains { $0.createdAt < cutoff }
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
    
    /// Fetches all threads sorted by sortOrder with default thread first (B-020).
    func refreshThreads() {
        guard let context = modelContext else {
            print("[ThoughtStreamModel] Cannot refresh threads without model context")
            return
        }
        
        do {
            let descriptor = FetchDescriptor<Thread>(
                sortBy: [SortDescriptor(\Thread.sortOrder, order: .forward)]
            )
            var fetchedThreads = try context.fetch(descriptor)
            
            // Ensure default thread is always first (B-020)
            if let defaultIndex = fetchedThreads.firstIndex(where: { $0.isDefault }) {
                let defaultThread = fetchedThreads.remove(at: defaultIndex)
                fetchedThreads.insert(defaultThread, at: 0)
            }
            
            threads = fetchedThreads
            print("[ThoughtStreamModel] Refreshed \(threads.count) threads (B-020)")
        } catch {
            print("[ThoughtStreamModel] Failed to fetch threads: \(error.localizedDescription)")
        }
    }
    
    /// Gets the last (most recent) thought for a given thread (B-020).
    /// Uses the thread's thoughts relationship for efficient access.
    func getLastThought(for thread: Thread) -> Thought? {
        // Use the thread's thoughts relationship directly (most efficient)
        // Sort by createdAt descending and get the first one
        let sortedThoughts = thread.thoughts.sorted { $0.createdAt > $1.createdAt }
        return sortedThoughts.first
    }
    
    /// Creates a new thread with the given name (B-022, B-031).
    /// Returns the created thread on success, nil on failure.
    /// Handles empty thread names gracefully (B-031).
    @discardableResult
    func createThread(name: String) -> Thread? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            print("[ThoughtStreamModel] Cannot create thread with empty name (B-031)")
            createThreadErrorMessage = "Thread name cannot be empty."
            return nil
        }
        
        guard let context = modelContext else {
            print("[ThoughtStreamModel] Cannot create thread without model context")
            createThreadErrorMessage = "Failed to create thread. Try again."
            return nil
        }
        
        // Get the highest sort order to place new thread at the end
        let maxSortOrder = threads.map { $0.sortOrder }.max() ?? 0
        let newSortOrder = maxSortOrder + 1
        
        let newThread = Thread(
            name: trimmedName,
            sortOrder: newSortOrder,
            isDefault: false
        )
        context.insert(newThread)
        
        do {
            try context.save()
            print("[ThoughtStreamModel] Created new thread '\(trimmedName)' with sort order \(newSortOrder) (B-022)")
            createThreadErrorMessage = nil
            refreshThreads()
            return newThread
        } catch {
            context.delete(newThread)
            print("[ThoughtStreamModel] Failed to create thread: \(error.localizedDescription)")
            createThreadErrorMessage = "Failed to create thread. Try again."
            return nil
        }
    }
    
    /// Clears the create thread error state.
    func acknowledgeCreateThreadError() {
        createThreadErrorMessage = nil
    }
    
    /// Renames a thread with the new name (B-026, B-031).
    /// Returns true on success, false on failure.
    /// Prevents renaming default thread and handles empty names gracefully (B-031).
    @discardableResult
    func renameThread(_ thread: Thread, newName: String) -> Bool {
        // Prevent renaming the default "Thoughts" thread (B-026, B-031)
        guard thread.isDefault == false else {
            print("[ThoughtStreamModel] Cannot rename default thread (B-031)")
            renameThreadErrorMessage = "The default 'Thoughts' thread cannot be renamed."
            return false
        }
        
        // Handle empty thread names gracefully (B-031)
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            print("[ThoughtStreamModel] Cannot rename thread with empty name (B-031)")
            renameThreadErrorMessage = "Thread name cannot be empty."
            return false
        }
        
        guard let context = modelContext else {
            print("[ThoughtStreamModel] Cannot rename thread without model context")
            renameThreadErrorMessage = "Failed to rename thread. Try again."
            return false
        }
        
        do {
            thread.name = trimmedName
            try context.save()
            print("[ThoughtStreamModel] Renamed thread to '\(trimmedName)' (B-026)")
            renameThreadErrorMessage = nil
            refreshThreads()
            
            // Update current thread if it's the one being renamed
            if currentThread?.id == thread.id {
                currentThread = thread
            }
            
            return true
        } catch {
            context.rollback()
            print("[ThoughtStreamModel] Failed to rename thread: \(error.localizedDescription)")
            renameThreadErrorMessage = "Failed to rename thread. Try again."
            return false
        }
    }
    
    /// Clears the rename thread error state.
    func acknowledgeRenameThreadError() {
        renameThreadErrorMessage = nil
    }
    
    /// Deletes a thread and all its thoughts (B-027, B-031).
    /// Returns true on success, false on failure.
    /// Prevents deletion of the default "Thoughts" thread (B-031).
    @discardableResult
    func deleteThread(_ thread: Thread) -> Bool {
        // Prevent deletion of the default "Thoughts" thread (B-027, B-031)
        guard thread.isDefault == false else {
            print("[ThoughtStreamModel] Cannot delete default thread (B-031)")
            deleteThreadErrorMessage = "The default 'Thoughts' thread cannot be deleted."
            return false
        }
        
        guard let context = modelContext else {
            print("[ThoughtStreamModel] Cannot delete thread without model context")
            deleteThreadErrorMessage = "Failed to delete thread. Try again."
            return false
        }
        
        // Check if this is the current thread - if so, switch to default thread first (B-027)
        let wasCurrentThread = currentThread?.id == thread.id
        
        do {
            // Delete the thread (cascade delete will remove all associated thoughts)
            context.delete(thread)
            try context.save()
            print("[ThoughtStreamModel] Deleted thread '\(thread.name)' and all its thoughts (B-027)")
            deleteThreadErrorMessage = nil
            
            // If this was the current thread, switch to default thread (B-027)
            if wasCurrentThread {
                setDefaultThreadAsCurrent()
                refreshThoughts()
            }
            
            // Refresh thread list
            refreshThreads()
            return true
        } catch {
            context.rollback()
            print("[ThoughtStreamModel] Failed to delete thread: \(error.localizedDescription)")
            deleteThreadErrorMessage = "Failed to delete thread. Try again."
            return false
        }
    }
    
    /// Clears the delete thread error state.
    func acknowledgeDeleteThreadError() {
        deleteThreadErrorMessage = nil
    }
    
    /// Reorders threads by moving a thread from source index to destination index (B-028).
    /// The default thread always stays at index 0 and cannot be moved.
    func reorderThreads(from source: IndexSet, to destination: Int) {
        guard let context = modelContext else {
            print("[ThoughtStreamModel] Cannot reorder threads without model context")
            reorderThreadErrorMessage = "Failed to save order. Try again."
            return
        }
        
        // Store original order for rollback on error
        let originalThreads = threads
        let originalSortOrders = threads.map { $0.sortOrder }
        
        // Prevent moving the default thread (always at index 0)
        guard let sourceIndex = source.first, sourceIndex > 0 else {
            print("[ThoughtStreamModel] Cannot move default thread")
            reorderThreadErrorMessage = "The default 'Thoughts' thread cannot be moved."
            return
        }
        
        // Prevent moving to index 0 (default thread position)
        guard destination > 0 else {
            print("[ThoughtStreamModel] Cannot move thread to default thread position")
            reorderThreadErrorMessage = "Cannot move thread above the default 'Thoughts' thread."
            return
        }
        
        // Adjust destination if moving down (account for removed item)
        let adjustedDestination = destination > sourceIndex ? destination - 1 : destination
        
        // Ensure destination is valid
        guard adjustedDestination > 0, adjustedDestination < threads.count else {
            print("[ThoughtStreamModel] Invalid destination index")
            reorderThreadErrorMessage = "Failed to save order. Try again."
            return
        }
        
        do {
            // Move thread in array
            var reorderedThreads = threads
            let movedThread = reorderedThreads.remove(at: sourceIndex)
            reorderedThreads.insert(movedThread, at: adjustedDestination)
            
            // Update sortOrder values based on new positions (B-028)
            // Default thread stays at sortOrder 0, others start at 1
            for (index, thread) in reorderedThreads.enumerated() {
                thread.sortOrder = index
            }
            
            // Save to SwiftData
            try context.save()
            print("[ThoughtStreamModel] Reordered threads: moved from index \(sourceIndex) to \(adjustedDestination) (B-028)")
            reorderThreadErrorMessage = nil
            
            // Refresh thread list to reflect new order
            refreshThreads()
        } catch {
            // Rollback: restore original sort orders
            for (index, thread) in originalThreads.enumerated() {
                thread.sortOrder = originalSortOrders[index]
            }
            context.rollback()
            print("[ThoughtStreamModel] Failed to reorder threads: \(error.localizedDescription)")
            reorderThreadErrorMessage = "Failed to save order. Try again."
        }
    }
    
    /// Clears the reorder thread error state.
    func acknowledgeReorderThreadError() {
        reorderThreadErrorMessage = nil
    }
    
    /// Switches to the specified thread and loads its thoughts (B-023, B-032).
    /// Optimized for performance with efficient queries and smooth transitions.
    func switchThread(_ thread: Thread) {
        guard modelContext != nil else {
            print("[ThoughtStreamModel] Cannot switch thread without model context")
            switchThreadErrorMessage = "Failed to load thread. Try again."
            return
        }
        
        // Set switching state for UI transitions (B-032)
        isSwitchingThread = true
        
        // Verify thread exists by checking if it's in our threads list
        // or by using the thread directly (it should already be a managed object)
        // Use the thread directly if it's already a managed object
        // Otherwise, try to find it in our threads list
        let validThread: Thread
        if let existingThread = threads.first(where: { $0.id == thread.id }) {
            validThread = existingThread
        } else {
            // Thread might be newly created, use it directly
            validThread = thread
        }
        
        // Update current thread first (B-032)
        currentThread = validThread
        switchThreadErrorMessage = nil
        
        // Clear existing thoughts and reset pagination state (B-032)
        thoughts = []
        oldestLoadedDate = nil
        canLoadOlder = false
        
        // Load thoughts for the new thread using efficient relationship access (B-032)
        // This uses thread.thoughts directly, which is already loaded and efficient
        refreshThoughts()
        
        // Clear switching state after a brief delay to allow UI to update (B-032)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            isSwitchingThread = false
        }
        
        print("[ThoughtStreamModel] Switched to thread '\(validThread.name)' (B-023, B-032)")
    }
    
    /// Clears the switch thread error state.
    func acknowledgeSwitchThreadError() {
        switchThreadErrorMessage = nil
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

