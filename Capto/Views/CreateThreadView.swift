//
//  CreateThreadView.swift
//  Capto
//
//  Created by Cursor GPT on 11/17/25.
//

import SwiftUI

/// Create thread screen with text field for naming new thread (S-003, B-022).
struct CreateThreadView: View {
    @Bindable var model: ThoughtStreamModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var threadName: String = ""
    
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
                            createThread()
                        }
                    
                    // Error message if creation fails
                    if let errorMessage = model.createThreadErrorMessage {
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
            .navigationTitle("New Thread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createThread()
                    }
                    .fontWeight(.semibold)
                    .disabled(threadName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                // Auto-focus text field when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + DesignSystem.ScrollTiming.focusDelay) {
                    isTextFieldFocused = true
                }
            }
        }
    }
    
    /// Creates the thread and dismisses the view on success (B-022).
    private func createThread() {
        let trimmedName = threadName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            print("[CreateThreadView] Attempted to create thread with empty name")
            return
        }
        
        if let newThread = model.createThread(name: trimmedName) {
            print("[CreateThreadView] Thread '\(trimmedName)' created successfully (B-022)")
            dismiss()
            // Note: Thread switching will be implemented in B-023
        } else {
            print("[CreateThreadView] Failed to create thread '\(trimmedName)'")
            // Error message is already set in model
        }
    }
}

#Preview {
    let model = ThoughtStreamModel()
    return CreateThreadView(model: model)
}

