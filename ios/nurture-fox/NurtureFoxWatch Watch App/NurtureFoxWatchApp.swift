//
//  NurtureFoxWatchApp.swift
//  NurtureFoxWatch Watch App
//
//  Created by Tim OLeary on 1/14/26.
//

import SwiftUI
import SwiftData

@main
struct NurtureFoxWatch_Watch_AppApp: App {
    // 1. Create the same shared container logic as the Phone
    var sharedModelContainer: ModelContainer = {
        let groupID = "group.toleary.nurture-fox" // Must match the phone exactly
        let schema = Schema([
            BabyEvent.self,
            Milestone.self
        ])
        let modelConfiguration = ModelConfiguration(groupContainer: .identifier(groupID))

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            WatchContentView() // Ensure this matches your Watch Content View name
        }
        .modelContainer(sharedModelContainer)
    }
}
