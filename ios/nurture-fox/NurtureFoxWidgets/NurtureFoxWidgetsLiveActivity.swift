import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct NurtureFoxLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            // --- LOCK SCREEN UI ---
            HStack(spacing: 0) {
                // 1. Accent Bar: Helps define the card shape on any wallpaper
                Rectangle()
                    .fill(Color.orange.gradient)
                    .frame(width: 6)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(context.attributes.babyName) • Last Feed")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        
                        // Added .id() to force the Lock Screen to recognize the timer as "live"
                        Text(context.state.startTime, style: .timer)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.primary)
                            .id(context.state.startTime)
                    }
                    
                    Spacer()
                    
                    // Bottle Icon
                    Image(systemName: "drop.fill")
                        .font(.title)
                        .foregroundStyle(.blue.gradient)
                        .padding(12)
                        .background(.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .activityBackgroundTint(Color.clear)
            .activitySystemActionForegroundColor(.primary)
            .background(.ultraThinMaterial)

        } dynamicIsland: { context in
            DynamicIsland {
                // 1. EXPANDED VIEW (Long-press)
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundColor(.orange)
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
                            .monospacedDigit()
                            .foregroundColor(.orange)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
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
                    .padding(.top, 5)
                }

            } compactLeading: {
                Image(systemName: "drop.fill")
                    .foregroundColor(.orange)
            } compactTrailing: {
                Text(context.state.startTime, style: .timer)
                    .monospacedDigit()
                    .foregroundColor(.orange)
                    .frame(width: 45)
            } minimal: {
                Image(systemName: "drop.fill")
                    .foregroundColor(.orange)
            }
        }
    }
}
