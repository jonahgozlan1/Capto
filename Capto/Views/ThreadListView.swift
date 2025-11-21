//
//  ThreadListView.swift
//  Capto
//
//  Created by Cursor GPT on 11/17/25.
//

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

/// Thread list screen showing all threads with name and last thought preview (S-002, B-020).
struct ThreadListView: View {
    @Bindable var model: ThoughtStreamModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isCreateThreadPresented = false
    @State private var threadToRename: Thread?
    @State private var threadToDelete: Thread?
    @State private var isDeleteDialogPresented = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(model.threads) { thread in
                    threadRow(for: thread)
                }
                // Intuitive drag-and-drop reordering (B-028, B-033)
                .onMove { source, destination in
                    print("[ThreadListView] Thread reorder requested: from \(source) to \(destination) (B-028, B-033)")
                    // Trigger haptic feedback for better UX (B-033)
                    #if os(iOS)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.prepare()
                    generator.impactOccurred()
                    #endif
                    model.reorderThreads(from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground).ignoresSafeArea())
            // Smooth scrolling for polished feel (B-033)
            .scrollIndicators(.hidden)
            .navigationTitle("Threads")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        print("[ThreadListView] New thread button tapped (B-022)")
                        isCreateThreadPresented = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
            .alert("Failed to load thread. Try again.", isPresented: .constant(model.switchThreadErrorMessage != nil), actions: {
                Button("OK") {
                    model.acknowledgeSwitchThreadError()
                }
            }, message: {
                Text(model.switchThreadErrorMessage ?? "")
            })
            .confirmationDialog(
                "Delete '\(threadToDelete?.name ?? "")'?",
                isPresented: $isDeleteDialogPresented,
                titleVisibility: .visible,
                presenting: threadToDelete,
                actions: { thread in
                    Button("Delete", role: .destructive) {
                        confirmThreadDeletion(thread)
                    }
                    Button("Cancel", role: .cancel) {
                        cancelThreadDeletion()
                    }
                },
                message: { thread in
                    Text("All thoughts in this thread will be permanently deleted.")
                }
            )
            .alert("Failed to delete thread. Try again.", isPresented: .constant(model.deleteThreadErrorMessage != nil), actions: {
                Button("OK") {
                    model.acknowledgeDeleteThreadError()
                }
            }, message: {
                Text(model.deleteThreadErrorMessage ?? "")
            })
            .alert("Failed to save order. Try again.", isPresented: .constant(model.reorderThreadErrorMessage != nil), actions: {
                Button("OK") {
                    model.acknowledgeReorderThreadError()
                }
            }, message: {
                Text(model.reorderThreadErrorMessage ?? "")
            })
            .sheet(isPresented: $isCreateThreadPresented, onDismiss: {
                // Refresh thread list when create thread sheet dismisses (B-022)
                model.refreshThreads()
                print("[ThreadListView] Create thread sheet dismissed, refreshed threads (B-022)")
            }) {
                CreateThreadView(model: model)
            }
            .sheet(item: $threadToRename) { thread in
                RenameThreadView(model: model, thread: thread)
            }
            .onAppear {
                model.configureContextIfNeeded(modelContext)
                model.refreshThreads()
                print("[ThreadListView] Thread list appeared (B-020)")
            }
        }
    }
    
    /// Creates a thread row view with swipe actions (B-027).
    @ViewBuilder
    private func threadRow(for thread: Thread) -> some View {
        ThreadRowView(
            thread: thread,
            lastThought: model.getLastThought(for: thread),
            onTap: {
                print("[ThreadListView] Thread '\(thread.name)' tapped (B-023)")
                model.switchThread(thread)
                dismiss()
            },
            onRename: {
                print("[ThreadListView] Rename requested for thread '\(thread.name)' (B-026)")
                threadToRename = thread
            }
        )
        // Optimized spacing and padding for polished UI (B-033)
        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
        .listRowSeparator(.hidden)
        // Prevent dragging the default thread (B-028, B-031)
        .moveDisabled(thread.isDefault)
        // Natural swipe gesture with haptic feedback (B-033)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Only show delete for non-default threads (B-027, B-031)
            // Prevents deletion of the default "Thoughts" thread (B-031)
            if thread.isDefault == false {
                Button(role: .destructive) {
                    print("[ThreadListView] Delete requested for thread '\(thread.name)' (B-027, B-033)")
                    // Haptic feedback for swipe action (B-033)
                    #if os(iOS)
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.prepare()
                    generator.impactOccurred()
                    #endif
                    threadToDelete = thread
                    isDeleteDialogPresented = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
    
    /// Empty state when no threads exist (shouldn't happen with default thread, but included for safety).
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No threads yet")
                .font(.headline)
            Text("Create your first thread to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    
    /// Confirms thread deletion and deletes the thread (B-027).
    private func confirmThreadDeletion(_ thread: Thread) {
        print("[ThreadListView] Confirming delete for thread '\(thread.name)' (B-027)")
        if model.deleteThread(thread) {
            print("[ThreadListView] Thread '\(thread.name)' deleted successfully (B-027)")
        } else {
            print("[ThreadListView] Failed to delete thread '\(thread.name)'")
        }
        threadToDelete = nil
        isDeleteDialogPresented = false
    }
    
    /// Cancels thread deletion (B-027).
    private func cancelThreadDeletion() {
        print("[ThreadListView] Cancelled thread deletion (B-027)")
        threadToDelete = nil
        isDeleteDialogPresented = false
    }
}

/// Individual thread row showing thread name and last thought preview (B-020, B-023, B-026).
private struct ThreadRowView: View {
    let thread: Thread
    let lastThought: Thought?
    let onTap: () -> Void
    let onRename: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                // Thread name (B-033)
                Text(thread.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                // Last thought preview with optimized length (B-033)
                if let lastThought = lastThought {
                    Text(truncatedPreview(for: lastThought.content))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("No thoughts yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
            
            Spacer()
            
            // Chevron indicator (B-033)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.tertiary)
                .opacity(0.5)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        // Natural long-press gesture for context menu (B-033)
        .contextMenu {
            // Only show rename option for non-default threads (B-026, B-031)
            // Prevents renaming the default "Thoughts" thread (B-031)
            if thread.isDefault == false {
                Button(action: onRename) {
                    Label("Rename", systemImage: "pencil")
                }
            }
        }
    }
    
    /// Truncates preview text to optimal length for thread list (B-033).
    /// Limits to approximately 80 characters to fit nicely in 2 lines.
    private func truncatedPreview(for text: String) -> String {
        let maxLength = 80
        if text.count <= maxLength {
            return text
        }
        // Truncate at word boundary near max length
        let truncated = String(text.prefix(maxLength))
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "..."
        }
        return truncated + "..."
    }
}

#Preview {
    do {
        let schema = Schema([Thought.self, Thread.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        
        // Create preview threads
        let defaultThread = Thread(name: "Thoughts", sortOrder: 0, isDefault: true)
        let workThread = Thread(name: "Work Ideas", sortOrder: 1, isDefault: false)
        let personalThread = Thread(name: "Personal", sortOrder: 2, isDefault: false)
        
        context.insert(defaultThread)
        context.insert(workThread)
        context.insert(personalThread)
        
        // Create preview thoughts
        let thought1 = Thought(content: "This is a preview thought in the default thread.", thread: defaultThread)
        let thought2 = Thought(content: "A work-related idea that needs to be captured.", thread: workThread)
        let thought3 = Thought(content: "Personal note about something important.", thread: personalThread)
        
        context.insert(thought1)
        context.insert(thought2)
        context.insert(thought3)
        
        let model = ThoughtStreamModel()
        model.configureContextIfNeeded(context)
        model.refreshThreads()
        
        return ThreadListView(model: model)
            .modelContainer(container)
    } catch {
        return Text("Failed to load preview: \(error.localizedDescription)")
    }
}

