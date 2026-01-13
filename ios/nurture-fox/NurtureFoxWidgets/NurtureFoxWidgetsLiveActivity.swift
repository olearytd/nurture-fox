//
//  NurtureFoxWidgetsLiveActivity.swift
//  NurtureFoxWidgets
//
//  Created by Tim OLeary on 1/13/26.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct NurtureFoxLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            // LOCK SCREEN UI
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(context.attributes.babyName) • Last Feed")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(context.state.startTime, style: .timer)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                    }
                    Spacer()
                    Image(systemName: "drop.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.blue.gradient)
                }
            }
            .padding()
            .activityBackgroundTint(Color.white.opacity(0.5)) // Semi-transparent look
        } dynamicIsland: { context in
            DynamicIsland {
                // 1. EXPANDED VIEW (Long-press)
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundColor(.blue)
                        Text(context.attributes.babyName)
                            .font(.headline)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("Last Feed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(context.state.startTime, style: .timer)
                            .font(.title2.bold())
                            .monospacedDigit() // Prevents text "jumping"
                            .foregroundColor(.blue)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    // Quick Action Buttons
                    HStack(spacing: 15) {
                        Button(intent: LogDiaperIntent(type: "Pee")) {
                            Label("Pee", systemImage: "drop")
                        }
                        .buttonStyle(.bordered)
                        .tint(.yellow)
                        
                        Button(intent: LogDiaperIntent(type: "Poop")) {
                            Label("Poop", systemImage: "brown.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(.brown)
                    }
                }

            } compactLeading: {
                // The left side of the "bubble"
                Image(systemName: "drop.fill")
                    .foregroundColor(.blue)
            } compactTrailing: {
                // The right side of the "bubble"
                Text(context.state.startTime, style: .timer)
                    .monospacedDigit()
                    .foregroundColor(.blue)
                    .frame(width: 45) // Fixed width prevents the island from stretching
            } minimal: {
                // Shown when multiple apps have activities
                Image(systemName: "drop.fill")
                    .foregroundColor(.blue)
            }
        }
    }
}
