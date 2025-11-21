//
//  Thread.swift
//  Capto
//
//  Created by Cursor GPT on 11/17/25.
//

import Foundation
import SwiftData

/// SwiftData model representing a thread for organizing thoughts (D-002).
/// Each thread can contain multiple thoughts, and users can create custom threads
/// in addition to the default "Thoughts" thread.
@Model
final class Thread {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var sortOrder: Int
    var isDefault: Bool
    
    /// Relationship: All thoughts that belong to this thread.
    @Relationship(deleteRule: .cascade, inverse: \Thought.thread)
    var thoughts: [Thought] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        sortOrder: Int = 0,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.isDefault = isDefault
    }
}

