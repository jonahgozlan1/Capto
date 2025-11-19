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
                Thought.self
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            print("[CaptoApp] SwiftData container ready at \(String(describing: container.configurations.first?.url.absoluteString))")
            return container
        } catch {
            fatalError("[CaptoApp] Failed to set up SwiftData container: \(error.localizedDescription)")
        }
    }()

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
