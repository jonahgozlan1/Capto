//
//  Thought.swift
//  Capto
//
//  Created by Cursor GPT on 11/17/25.
//

import Foundation
import SwiftData

/// SwiftData model representing a single captured thought (D-001).
@Model
final class Thought {
    @Attribute(.unique) var id: UUID
    var content: String
    var createdAt: Date

    init(id: UUID = UUID(), content: String, createdAt: Date = Date()) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
    }
}

