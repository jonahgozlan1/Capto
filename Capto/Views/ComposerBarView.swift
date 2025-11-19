//
//  ComposerBarView.swift
//  Capto
//
//  Created by Refactoring on 01/27/25.
//

import SwiftUI

/// The fixed composer anchored to the safe area bottom.
struct ComposerBarView: View {
    @Bindable var model: ThoughtStreamModel
    @FocusState.Binding var isComposerFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    let sendAction: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            TextField("What's on your mind?", text: $model.draftText, axis: .vertical)
                .focused($isComposerFocused)
                .textFieldStyle(.plain)
                .submitLabel(.return)
                .onSubmit {
                    sendAction()
                }
                .padding(.vertical, DesignSystem.Spacing.composerTextFieldVertical)
                .padding(.horizontal, DesignSystem.Spacing.composerTextFieldHorizontal)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.composerTextField, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.composerTextField, style: .continuous)
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
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.composerTextField, style: .continuous)
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

            Button(action: sendAction) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 40, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(model.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.accentColor)
                    .scaleEffect(model.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1.0 : 1.05)
            }
            .accessibilityLabel("Send thought")
            .disabled(model.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .animation(.spring(response: DesignSystem.Animation.springResponse, dampingFraction: DesignSystem.Animation.springDamping), value: model.draftText.isEmpty)
        }
        .padding(.vertical, DesignSystem.Spacing.composerVertical)
        .padding(.horizontal, DesignSystem.Spacing.composerHorizontal)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.composer, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.composer, style: .continuous)
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
                    radius: DesignSystem.Shadow.composerRadius,
                    y: DesignSystem.Shadow.composerY
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.05),
                    radius: DesignSystem.Shadow.composerRadiusSecondary,
                    y: DesignSystem.Shadow.composerYSecondary
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
}

