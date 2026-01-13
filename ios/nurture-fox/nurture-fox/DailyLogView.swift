//
//  DailyLogView.swift
//  nurture-fox
//
//  Created by Tim OLeary on 1/9/26.
//


import SwiftUI
import SwiftData
import ActivityKit

struct DailyLogView: View {
    @Environment(\.modelContext) private var modelContext
    
    // This automatically fetches and updates the list when data changes
    @Query(sort: \BabyEvent.timestamp, order: .reverse) private var events: [BabyEvent]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(events) { event in
                    HStack(spacing: 16) {
                        // Icon based on type
                        ZStack {
                            Circle()
                                .fill(event.type == "FEED" ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: event.type == "FEED" ? "mouth.fill" : "tent.fill")
                                .foregroundColor(event.type == "FEED" ? .blue : .green)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(event.type == "FEED" ? "Feed: \(event.amount, specifier: "%.1f") \(event.subtype)" : "Diaper: \(event.subtype)")
                                .font(.headline)
                            
                            Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteItems) // Swiping to delete
            }
            .navigationTitle("Daily Log")
            .overlay {
                if events.isEmpty {
                    ContentUnavailableView("No Logs Yet", systemImage: "list.bullet.rectangle.portrait", description: Text("Logged events will appear here."))
                }
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let event = events[index]
                // If deleting a feed, kill the active timer
                if event.type == "FEED" {
                    endAllLiveActivities()
                }
                modelContext.delete(event)
            }
        }
    }
    
    private func endAllLiveActivities() {
        Task {
            for activity in Activity<TimerAttributes>.activities {
                // DismissalPolicy: .immediate makes it vanish instantly
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
