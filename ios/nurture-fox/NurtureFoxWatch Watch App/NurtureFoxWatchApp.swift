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
    var sharedModelContainer: ModelContainer = {
        let groupID = "group.toleary.nurture-fox" // Must match the phone exactly
        let schema = Schema([
            BabyEvent.self,
            Milestone.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(groupID),
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("Watch ModelContainer error: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
