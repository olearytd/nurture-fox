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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(scheme)
        }
        .modelContainer(for: [BabyEvent.self, Milestone.self])
    }
    
    // Logic to switch theme globally
    var scheme: ColorScheme? {
        switch themePreference {
        case 1: return .light
        case 2: return .dark
        default: return nil // System default
        }
    }
}
