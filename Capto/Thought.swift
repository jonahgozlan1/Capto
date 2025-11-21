//
//  Thought.swift
//  Capto
//
//  Created by Cursor GPT on 11/17/25.
//

import Foundation
import SwiftData

/// SwiftData model representing a single captured thought (D-001).
/// Updated in B-019 to include thread relationship.
@Model
final class Thought {
    @Attribute(.unique) var id: UUID
    var content: String
    var createdAt: Date
    
    /// Relationship: The thread this thought belongs to (B-019).
    /// All thoughts must be associated with a thread, typically the default "Thoughts" thread.
    var thread: Thread?

    init(id: UUID = UUID(), content: String, createdAt: Date = Date(), thread: Thread? = nil) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.thread = thread
    }
}

