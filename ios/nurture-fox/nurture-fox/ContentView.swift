//
//  ContentView.swift
//  nurture-fox
//
//  Created by Tim OLeary on 1/9/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TrackerView()
                .tabItem { Label("Tracker", systemImage: "timer") }
                .tag(0)
            
            DailyLogView()
                .tabItem { Label("Log", systemImage: "list.bullet") }
                .tag(1)
            
            TrendsView()
                .tabItem { Label("Trends", systemImage: "chart.bar") }
                .tag(2)
            
            MilestonesView()
                .tabItem { Label("Milestones", systemImage: "star") }
                .tag(3)
        }
        // Force the environment into the TabView children explicitly
        .environment(\.modelContext, modelContext)
        // This 'id' trick prevents the EXC_BAD_ACCESS by resetting the
        // view lifecycle if the data context becomes stale.
        .id(selectedTab)
    }
}
