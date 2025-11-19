//
//  TimestampManager.swift
//  Capto
//
//  Created by Refactoring on 01/27/25.
//

import Foundation
import SwiftUI
import Observation

/// Manages timestamp visibility state and auto-hide scheduling.
@Observable
@MainActor
final class TimestampManager {
    /// Set of thought IDs whose timestamps are currently visible.
    var revealedTimestampIDs: Set<UUID> = []
    
    /// Active hide tasks keyed by thought ID.
    private var timestampHideTasks: [UUID: DispatchWorkItem] = [:]
    
    /// Reveals timestamp and schedules auto-hide after 3.5 seconds.
    func revealTimestampTemporarily(for id: UUID) {
        logDebug("[TimestampManager] Revealing timestamp for \(id)")
        
        // Cancel any existing hide task for this timestamp
        cancelTimestampHideTask(for: id)
        
        // Hide all other timestamps (only one visible at a time)
        let otherIDs = revealedTimestampIDs.filter { $0 != id }
        if !otherIDs.isEmpty {
            otherIDs.forEach { cancelTimestampHideTask(for: $0) }
            withAnimation(.easeInOut(duration: DesignSystem.Animation.timestampDuration)) {
                revealedTimestampIDs.subtract(otherIDs)
            }
        }
        
        // Reveal this timestamp
        if !revealedTimestampIDs.contains(id) {
            _ = withAnimation(.easeInOut(duration: DesignSystem.Animation.timestampDuration)) {
                revealedTimestampIDs.insert(id)
            }
        }
        
        // Schedule auto-hide after 3.5 seconds
        let hideTask = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.revealedTimestampIDs.contains(id) {
                _ = withAnimation(.easeInOut(duration: DesignSystem.Animation.timestampDuration)) {
                    self.revealedTimestampIDs.remove(id)
                }
                logDebug("[TimestampManager] Auto-hiding timestamp for \(id)")
            }
            self.timestampHideTasks.removeValue(forKey: id)
        }
        timestampHideTasks[id] = hideTask
        DispatchQueue.main.asyncAfter(deadline: .now() + DesignSystem.ScrollTiming.timestampAutoHide, execute: hideTask)
    }
    
    /// Toggles timestamp visibility. If already visible, hides it immediately.
    func toggleTimestampVisibility(for id: UUID) {
        logDebug("[TimestampManager] Toggling timestamp visibility for \(id)")
        
        // If already visible, hide it immediately
        if revealedTimestampIDs.contains(id) {
            cancelTimestampHideTask(for: id)
            _ = withAnimation(.easeInOut(duration: DesignSystem.Animation.timestampDuration)) {
                revealedTimestampIDs.remove(id)
            }
            return
        }
        
        // Hide all other timestamps (only one visible at a time)
        hideAllTimestamps()
        
        // Reveal the new timestamp
        revealTimestampTemporarily(for: id)
    }
    
    /// Cancels the auto-hide task for a specific timestamp.
    func cancelTimestampHideTask(for id: UUID) {
        if let task = timestampHideTasks[id] {
            task.cancel()
            timestampHideTasks.removeValue(forKey: id)
        }
    }
    
    /// Hides all visible timestamps immediately (e.g., when scrolling starts).
    func hideAllTimestamps() {
        // Cancel all pending hide tasks
        timestampHideTasks.values.forEach { $0.cancel() }
        timestampHideTasks.removeAll()
        
        // Hide all timestamps
        if !revealedTimestampIDs.isEmpty {
            withAnimation(.easeInOut(duration: DesignSystem.Animation.timestampDuration)) {
                revealedTimestampIDs.removeAll()
            }
            logDebug("[TimestampManager] Hiding all timestamps")
        }
    }
    
    /// Removes timestamp IDs that no longer correspond to existing thoughts.
    func trimTimestampSelections(validIDs: Set<UUID>) {
        let filtered = revealedTimestampIDs.intersection(validIDs)
        if filtered != revealedTimestampIDs {
            logDebug("[TimestampManager] Trimming timestamp selections to existing thoughts")
            revealedTimestampIDs = filtered
        }
    }
}

