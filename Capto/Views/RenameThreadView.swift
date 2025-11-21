//
//  RenameThreadView.swift
//  Capto
//
//  Created by Cursor GPT on 11/17/25.
//

import SwiftUI

/// Rename thread screen with text field pre-filled with current thread name (S-004, B-026).
struct RenameThreadView: View {
    @Bindable var model: ThoughtStreamModel
    let thread: Thread
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var threadName: String
    
    init(model: ThoughtStreamModel, thread: Thread) {
        self.model = model
        self.thread = thread
        // Pre-fill with current thread name (B-026)
        self._threadName = State(initialValue: thread.name)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Text field for thread name
                VStack(alignment: .leading, spacing: 12) {
                    Text("Thread Name")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                    
                    TextField("Enter thread name", text: $threadName)
                        .focused($isTextFieldFocused)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(false)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
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
                        .padding(.horizontal, 20)
                        .onSubmit {
                            renameThread()
                        }
                    
                    // Error message if rename fails
                    if let errorMessage = model.renameThreadErrorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .font(.system(size: 14))
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                }
                
                Spacer()
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("Rename Thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        model.acknowledgeRenameThreadError()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        renameThread()
                    }
                    .fontWeight(.semibold)
                    // Disable save button when thread name is empty (B-031)
                    .disabled(threadName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                // Auto-focus text field and select all text when view appears (B-026)
                DispatchQueue.main.asyncAfter(deadline: .now() + DesignSystem.ScrollTiming.focusDelay) {
                    isTextFieldFocused = true
                    // Select all text for easy editing
                    // Note: TextField doesn't support programmatic text selection in SwiftUI,
                    // but auto-focus allows user to easily select all
                }
            }
        }
    }
    
    /// Renames the thread and dismisses the view on success (B-026).
    private func renameThread() {
        let trimmedName = threadName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            print("[RenameThreadView] Attempted to rename thread with empty name")
            return
        }
        
        // Only rename if name actually changed
        guard trimmedName != thread.name else {
            print("[RenameThreadView] Thread name unchanged, dismissing")
            dismiss()
            return
        }
        
        if model.renameThread(thread, newName: trimmedName) {
            print("[RenameThreadView] Thread renamed to '\(trimmedName)' successfully (B-026)")
            dismiss()
        } else {
            print("[RenameThreadView] Failed to rename thread to '\(trimmedName)'")
            // Error message is already set in model
        }
    }
}

#Preview {
    let model = ThoughtStreamModel()
    let previewThread = Thread(name: "Work Ideas", sortOrder: 1, isDefault: false)
    return RenameThreadView(model: model, thread: previewThread)
}

