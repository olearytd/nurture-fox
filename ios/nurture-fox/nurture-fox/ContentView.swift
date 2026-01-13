//
//  ContentView.swift
//  nurture-fox
//
//  Created by Tim OLeary on 1/9/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            TrackerView()
                .tabItem {
                    Label("Tracker", systemImage: "timer")
                }
                .tag(0)
            
            DailyLogView()
                .tabItem {
                    Label("Daily Log", systemImage: "list.bullet.rectangle")
                }
                .tag(1)
            
            TrendsView()
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)
            
            MilestonesView()
                .tabItem {
                    Label("Milestones", systemImage: "star.fill")
                }
                .tag(3)
        }
    }
}
