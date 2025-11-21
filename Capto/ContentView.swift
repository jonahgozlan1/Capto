//
//  ContentView.swift
//  Capto
//
//  Created by Jonah Gozlan on 11/17/25.
//

import SwiftUI
import Observation
import SwiftData
import UIKit

/// Main thought stream layout (B-002) with SwiftData-backed state (B-003).
struct ContentView: View {
    @Bindable var model: ThoughtStreamModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    @FocusState private var isComposerFocused: Bool
    @State private var revealedTimestampIDs: Set<UUID> = []
    @State private var pendingDeletionThought: Thought?
    @State private var isDeleteDialogPresented = false
    @State private var isSearchPresented = false
    @State private var isThreadListPresented = false
    @State private var hasAppliedInitialFocus = false
    @State private var pendingFocusTask: DispatchWorkItem?
    @State private var timestampHideTasks: [UUID: DispatchWorkItem] = [:]

    init(model: ThoughtStreamModel) {
        self.model = model
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Color(.systemBackground)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isComposerFocused {
                                print("[ContentView] Tap detected on background, dismissing keyboard")
                                releaseKeyboardFocus(reason: "tap outside")
                            }
                        }

                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(alignment: .center, spacing: 12, pinnedViews: []) {
                                if model.thoughts.isEmpty && !model.isSwitchingThread {
                                    emptyState
                                } else {
                                    if model.isLoadingOlder {
                                        LoadingOlderIndicator()
                                    }
                                    if let loadError = model.loadOlderErrorMessage {
                                        LoadErrorBanner(message: loadError)
                                    }
                                    if let searchError = model.searchErrorMessage {
                                        SearchErrorBanner(message: searchError)
                                    }
                                    // Smooth transition when switching threads (B-032)
                                    ThoughtStreamView(
                                        sections: model.thoughtSections,
                                        availableWidth: geometry.size.width,
                                        isTimestampVisible: { id in
                                            revealedTimestampIDs.contains(id)
                                        },
                                        toggleTimestamp: toggleTimestampVisibility(for:),
                                        revealTimestamp: revealTimestampTemporarily(for:),
                                        requestDelete: requestDeletion(for:)
                                    )
                                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                                    .animation(.easeInOut(duration: 0.25), value: model.currentThread?.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 24)
                            .padding(.bottom, 12) // Leaves space for the composer inset.
                        }
                        .defaultScrollAnchor(.bottom) // Start at bottom on launch (iOS 17+)
                        .scrollDismissesKeyboard(.interactively)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { _ in
                                    // Hide timestamps when user starts scrolling
                                    hideAllTimestamps()
                                }
                        )
                        .refreshable {
                            if model.canLoadOlder {
                                await model.loadOlderThoughts()
                            }
                        }
                        .onChange(of: model.thoughts.count) { oldCount, newCount in
                            print("🔍 onChange triggered: \(oldCount) -> \(newCount)")
                            print("🔍 All thought IDs:", model.thoughts.map { $0.id })
                            print("🔍 Last thought ID:", model.thoughts.last?.id ?? "none")
                            print("🔍 isLoadingOlder:", model.isLoadingOlder)
                            
                            trimTimestampSelections()
                            // Auto-scroll when new thought is added (count increased)
                            if newCount > oldCount, let lastThought = model.thoughts.last, !model.isLoadingOlder {
                                print("🔍 Last thought ID:", lastThought.id)
                                
                                // Wait for view to finish laying out before scrolling
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    print("🔍 Attempting scroll to thought ID:", lastThought.id)
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo(lastThought.id, anchor: .bottom)
                                        print("🔍 Called scrollTo with ID:", lastThought.id)
                                    }
                                }
                            } else {
                                print("🔍 Scroll condition not met - oldCount: \(oldCount), newCount: \(newCount), hasLastThought: \(model.thoughts.last != nil), isLoadingOlder: \(model.isLoadingOlder)")
                            }
                        }
                        .onChange(of: isComposerFocused) { oldValue, newValue in
                            // Auto-scroll to bottom when keyboard opens (iMessage style)
                            if newValue == true {
                                print("🔍 Keyboard opened, scrolling to bottom")
                                
                                // Small delay to sync with keyboard animation
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    if let lastThought = model.thoughts.last {
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            proxy.scrollTo(lastThought.id, anchor: .bottom)
                                        }
                                        print("🔍 Scrolled to bottom for keyboard")
                                    }
                                }
                            }
                        }
                        .onChange(of: model.currentThread?.id) { oldThreadID, newThreadID in
                            // Auto-scroll to bottom when thread changes with smooth animation (B-023, B-032)
                            if newThreadID != oldThreadID {
                                print("[ContentView] Thread changed, preparing smooth transition (B-032)")
                                // Wait for thoughts to load, then scroll with smooth animation
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    if let lastThought = model.thoughts.last {
                                        withAnimation(.easeOut(duration: 0.4)) {
                                            proxy.scrollTo(lastThought.id, anchor: .bottom)
                                        }
                                        print("[ContentView] Scrolled to bottom with smooth animation (B-032)")
                                    }
                                }
                            }
                        }
                        .onAppear {
                            print("🔍 ScrollView appeared")
                            print("🔍 Number of thoughts:", model.thoughts.count)
                            print("🔍 Thought IDs on appear:", model.thoughts.map { $0.id })
                            // Note: .defaultScrollAnchor(.bottom) handles initial positioning automatically
                        }
                    }
                }
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composerBar
            }
            .navigationTitle(model.currentThread?.name ?? "Capto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        print("[ContentView] Thread list button tapped (B-021)")
                        isThreadListPresented = true
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .accessibilityLabel("Threads")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: openSearch) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .accessibilityLabel("Search thoughts")
                }
            }
        }
        .confirmationDialog(
            "Delete this thought?",
            isPresented: $isDeleteDialogPresented,
            presenting: pendingDeletionThought,
            actions: { thought in
                Button("Delete", role: .destructive) {
                    confirmDeletion(of: thought)
                }
                Button("Cancel", role: .cancel) {
                    cancelDeletion()
                }
            },
            message: { _ in
                Text("This action cannot be undone.")
            }
        )
        .alert("Failed to delete thought. Try again.", isPresented: deleteErrorBinding, actions: {
            Button("OK", role: .cancel) {
                model.acknowledgeDeleteError()
            }
        }, message: {
            Text(model.deleteErrorMessage ?? "")
        })
        .sheet(isPresented: $isSearchPresented, onDismiss: {
            model.resetSearchState()
        }) {
            SearchView(model: model) {
                dismissSearch()
                    }
                }
        .sheet(isPresented: $isThreadListPresented) {
            ThreadListView(model: model)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Only auto-focus on initial launch, not when returning from background
            // This allows users to dismiss keyboard and have it stay dismissed
            if newPhase == .active && !hasAppliedInitialFocus {
                enforceKeyboardFocus(reason: "scene became active (first time)")
            }
        }
        .onChange(of: isSearchPresented) { _, presented in
            if presented == false {
                enforceKeyboardFocus(reason: "search dismissed", delay: 0.05)
            } else {
                releaseKeyboardFocus(reason: "search presented")
            }
        }
        .onChange(of: isThreadListPresented) { _, presented in
            if presented {
                releaseKeyboardFocus(reason: "thread list presented")
            }
        }
        .onChange(of: isDeleteDialogPresented) { _, presented in
            if presented {
                // Dismiss keyboard when delete confirmation dialog appears
                releaseKeyboardFocus(reason: "delete dialog presented")
            }
        }
        .onAppear {
            model.configureContextIfNeeded(modelContext)
            model.handleAppear()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                enforceKeyboardFocus(reason: hasAppliedInitialFocus ? "re-appear" : "initial mount")
                hasAppliedInitialFocus = true
                trimTimestampSelections()
            }
        }
    }

    /// Friendly empty state that still respects the centered bubble aesthetic.
    private var emptyState: some View {
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

    /// The fixed composer anchored to the safe area bottom.
    private var composerBar: some View {
        HStack(spacing: 16) {
            TextField("What's on your mind?", text: $model.draftText, axis: .vertical)
                .focused($isComposerFocused)
                .textFieldStyle(.plain)
                .submitLabel(.return)
                .onSubmit {
                    sendCurrentDraft()
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(colorScheme == .dark ? 0.04 : 0.12),
                                            Color.white.opacity(colorScheme == .dark ? 0.02 : 0.06)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.20),
                                    Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.05),
                    radius: 8,
                    y: 2
                )

            Button(action: sendCurrentDraft) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 40, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(model.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.accentColor)
                    .scaleEffect(model.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1.0 : 1.05)
            }
            .accessibilityLabel("Send thought")
            .disabled(model.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: model.draftText.isEmpty)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 22)
        .background(
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.06 : 0.15),
                                    Color.white.opacity(colorScheme == .dark ? 0.03 : 0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                    radius: 24,
                    y: 8
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.05),
                    radius: 48,
                    y: 16
                )
                .ignoresSafeArea()
        )
        .alert("Failed to save thought. Try again.", isPresented: sendErrorBinding, actions: {
            Button("OK", role: .cancel) {
                model.acknowledgeError()
            }
        }, message: {
            Text(model.sendErrorMessage ?? "")
        })
        .alert("Blank thought ignored", isPresented: blankSendBinding, actions: {
            Button("OK", role: .cancel) {
                model.acknowledgeBlankSendError()
            }
        }, message: {
            Text(model.blankSendErrorMessage ?? "Add some text before sending.")
        })
    }

    /// Sends the current draft and keeps the keyboard active for rapid entry.
    private func sendCurrentDraft() {
        if let newThought = model.sendDraft() {
            triggerSendHaptic()
            revealTimestampTemporarily(for: newThought.id)
            // Scroll is handled automatically by onChange(of: thoughts.count)
        }
        enforceKeyboardFocus(reason: "post-send", delay: 0.05)
    }

    private func openSearch() {
        releaseKeyboardFocus(reason: "search opened")
        model.resetSearchState()
        isSearchPresented = true
    }

    private func dismissSearch() {
        isSearchPresented = false
    }

    private func requestDeletion(for thought: Thought) {
        pendingDeletionThought = thought
        isDeleteDialogPresented = true
        triggerDeleteHaptic()
    }

    private func confirmDeletion(of thought: Thought) {
        print("[ContentView] Confirming delete for \(thought.id)")
        model.deleteThought(thought)
        pendingDeletionThought = nil
        isDeleteDialogPresented = false
        trimTimestampSelections()
    }

    private func cancelDeletion() {
        print("[ContentView] Cancelled delete dialog")
        pendingDeletionThought = nil
        isDeleteDialogPresented = false
    }

    /// Reveals timestamp and schedules auto-hide after 3.5 seconds (iMessage-style).
    private func toggleTimestampVisibility(for id: UUID) {
        print("[ContentView] Toggling timestamp visibility for \(id)")
        
        // If already visible, hide it immediately
        if revealedTimestampIDs.contains(id) {
            cancelTimestampHideTask(for: id)
            animate(.easeInOut(duration: 0.2)) {
                revealedTimestampIDs.remove(id)
            }
            return
        }
        
        // Hide all other timestamps (only one visible at a time)
        hideAllTimestamps()
        
        // Reveal the new timestamp
        revealTimestampTemporarily(for: id)
    }

    /// Reveals timestamp and schedules auto-hide after 3.5 seconds.
    private func revealTimestampTemporarily(for id: UUID) {
        print("[ContentView] Revealing timestamp for \(id)")
        
        // Cancel any existing hide task for this timestamp
        cancelTimestampHideTask(for: id)
        
        // Hide all other timestamps (only one visible at a time)
        // Cancel their hide tasks and remove them from the set
        let otherIDs = revealedTimestampIDs.filter { $0 != id }
        if !otherIDs.isEmpty {
            otherIDs.forEach { cancelTimestampHideTask(for: $0) }
            animate(.easeInOut(duration: 0.2)) {
                revealedTimestampIDs.subtract(otherIDs)
            }
        }
        
        // Reveal this timestamp (insert is idempotent if already present)
        if !revealedTimestampIDs.contains(id) {
            animate(.easeInOut(duration: 0.2)) {
                revealedTimestampIDs.insert(id)
            }
        }
        
        // Schedule auto-hide after 3.5 seconds
        let hideTask = DispatchWorkItem {
            // Access state directly - structs don't need weak references
            if revealedTimestampIDs.contains(id) {
                animate(.easeInOut(duration: 0.2)) {
                    revealedTimestampIDs.remove(id)
                }
                print("[ContentView] Auto-hiding timestamp for \(id)")
            }
            timestampHideTasks.removeValue(forKey: id)
        }
        timestampHideTasks[id] = hideTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5, execute: hideTask)
    }
    
    /// Cancels the auto-hide task for a specific timestamp.
    private func cancelTimestampHideTask(for id: UUID) {
        if let task = timestampHideTasks[id] {
            task.cancel()
            timestampHideTasks.removeValue(forKey: id)
        }
    }
    
    /// Hides all visible timestamps immediately (e.g., when scrolling starts).
    private func hideAllTimestamps() {
        // Cancel all pending hide tasks
        timestampHideTasks.values.forEach { $0.cancel() }
        timestampHideTasks.removeAll()
        
        // Hide all timestamps
        if !revealedTimestampIDs.isEmpty {
            animate(.easeInOut(duration: 0.2)) {
                revealedTimestampIDs.removeAll()
            }
            print("[ContentView] Hiding all timestamps")
        }
    }

    private func trimTimestampSelections() {
        let validIDs = Set(model.thoughts.map(\.id))
        let filtered = revealedTimestampIDs.intersection(validIDs)
        if filtered != revealedTimestampIDs {
            print("[ContentView] Trimming timestamp selections to existing thoughts")
            revealedTimestampIDs = filtered
        }
    }

    /// Derived binding that shows the alert when the model surfaces an error.
    private var sendErrorBinding: Binding<Bool> {
        Binding(
            get: { model.sendErrorMessage != nil },
            set: { newValue in
                if newValue == false {
                    model.acknowledgeError()
                }
            }
        )
    }

    private var blankSendBinding: Binding<Bool> {
        Binding(
            get: { model.blankSendErrorMessage != nil },
            set: { newValue in
                if newValue == false {
                    model.acknowledgeBlankSendError()
                }
            }
        )
    }

    private var deleteErrorBinding: Binding<Bool> {
        Binding(
            get: { model.deleteErrorMessage != nil },
            set: { newValue in
                if newValue == false {
                    model.acknowledgeDeleteError()
                }
            }
        )
    }

    /// Provides light haptic feedback to acknowledge a successful send.
    private func triggerSendHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    private func triggerDeleteHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    private func enforceKeyboardFocus(reason: String, delay: Double = 0.02) {
        pendingFocusTask?.cancel()
        let task = DispatchWorkItem {
            print("[ContentView] Enforcing keyboard focus (\(reason))")
            isComposerFocused = true
        }
        pendingFocusTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    private func releaseKeyboardFocus(reason: String) {
        pendingFocusTask?.cancel()
        pendingFocusTask = nil
        print("[ContentView] Releasing keyboard focus (\(reason))")
        isComposerFocused = false
    }

    private func animate(_ animation: Animation = .default, actions: @escaping () -> Void) {
        withAnimation(animation, actions)
    }
}

#Preview {
    do {
        let schema = Schema([Thought.self, Thread.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        
        // Create a mock default thread for preview (B-018)
        let previewThread = Thread(name: "Thoughts", sortOrder: 0, isDefault: true)
        context.insert(previewThread)
        
        let samples = [
            Thought(content: "Walked past a coffee shop that smelled amazing.", createdAt: Date().addingTimeInterval(-60), thread: previewThread),
            Thought(content: "Remember to send thank-you note.", createdAt: Date().addingTimeInterval(-3600), thread: previewThread),
            Thought(content: "Midnight idea: ambient rain toggle.", createdAt: Date().addingTimeInterval(-86400), thread: previewThread),
            Thought(content: "Goal for tomorrow: take 10k steps.", createdAt: Date().addingTimeInterval(-86400 * 2), thread: previewThread)
        ]
        samples.forEach { context.insert($0) }

        let model = ThoughtStreamModel()
        model.configureContextIfNeeded(context)
        model.refreshThoughts()
        return ContentView(model: model)
            .modelContainer(container)
    } catch {
        return Text("Failed to load preview: \(error.localizedDescription)")
    }
}
