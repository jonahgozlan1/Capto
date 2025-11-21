//
//  CaptoApp.swift
//  Capto
//
//  Created by Jonah Gozlan on 11/17/25.
//

import SwiftUI
import SwiftData

@main
struct CaptoApp: App {
    private let rootModel = ThoughtStreamModel()

    /// Shared SwiftData container scoped to the whole app lifecycle.
    private var sharedModelContainer: ModelContainer = {
        do {
            let schema = Schema([
                Thought.self,
                Thread.self
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            print("[CaptoApp] SwiftData container ready at \(String(describing: container.configurations.first?.url.absoluteString))")
            
            // Ensure default "Thoughts" thread exists on first launch (B-018)
            ensureDefaultThreadExists(in: container)
            
            return container
        } catch {
            fatalError("[CaptoApp] Failed to set up SwiftData container: \(error.localizedDescription)")
        }
    }()
    
    /// Creates the default "Thoughts" thread if it doesn't exist, and associates
    /// any existing thoughts without a thread to the default thread (B-018, B-019).
    private static func ensureDefaultThreadExists(in container: ModelContainer) {
        let context = ModelContext(container)
        
        do {
            // Check if default thread already exists
            let predicate = #Predicate<Thread> { thread in
                thread.isDefault == true
            }
            let descriptor = FetchDescriptor<Thread>(predicate: predicate)
            let existingDefaultThreads = try context.fetch(descriptor)
            
            let defaultThread: Thread
            if let existing = existingDefaultThreads.first {
                print("[CaptoApp] Default thread already exists: \(existing.name) (B-019)")
                defaultThread = existing
            } else {
                // Create default "Thoughts" thread
                defaultThread = Thread(
                    name: "Thoughts",
                    sortOrder: 0,
                    isDefault: true
                )
                context.insert(defaultThread)
                print("[CaptoApp] Created default 'Thoughts' thread (B-018, B-019)")
            }
            
            // Update any existing thoughts that don't have a thread assigned (B-019)
            let allThoughtsDescriptor = FetchDescriptor<Thought>()
            let allThoughts = try context.fetch(allThoughtsDescriptor)
            var updatedCount = 0
            var alreadyAssociatedCount = 0
            
            for thought in allThoughts {
                if thought.thread == nil {
                    thought.thread = defaultThread
                    updatedCount += 1
                } else {
                    alreadyAssociatedCount += 1
                }
            }
            
            // Verification logging for B-019
            if updatedCount > 0 {
                print("[CaptoApp] Associated \(updatedCount) existing thoughts with default thread (B-019)")
            }
            if alreadyAssociatedCount > 0 {
                print("[CaptoApp] Verified \(alreadyAssociatedCount) thoughts already associated with threads (B-019)")
            }
            print("[CaptoApp] Total thoughts: \(allThoughts.count), all now associated with threads (B-019)")
            
            try context.save()
        } catch {
            print("[CaptoApp] Error ensuring default thread exists: \(error.localizedDescription)")
            // Don't fatal error here - app can still function, just log the issue
        }
    }

    init() {
        print("[CaptoApp] Initializing root model and launching scene (B-003)")
    }

    var body: some Scene {
        WindowGroup {
            ContentView(model: rootModel)
        }
        .modelContainer(sharedModelContainer)
    }
}
