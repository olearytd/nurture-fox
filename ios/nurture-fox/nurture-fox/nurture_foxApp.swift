//
//  nurture_foxApp.swift
//  nurture-fox
//
//  Created by Tim OLeary on 1/9/26.
//

import SwiftUI
import SwiftData

@main
struct nurture_foxApp: App {
    @AppStorage("themePreference") private var themePreference: Int = 0
    
    // 1. Define the Shared Model Container with App Group support
    var sharedModelContainer: ModelContainer = {
        // MUST match the ID you checked in 'Signing & Capabilities'
        let groupID = "group.toleary.nurture-fox"
        let schema = Schema([
            BabyEvent.self,
            Milestone.self
        ])
        
        // This configuration tells SwiftData to save to the shared 'App Group' folder
        // which allows the Widget and Watch to 'see' the same data.
        let modelConfiguration = ModelConfiguration(groupContainer: .identifier(groupID))

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(scheme)
        }
        // 2. Pass the shared container here
        .modelContainer(sharedModelContainer)
    }
    
    var scheme: ColorScheme? {
        switch themePreference {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
}
