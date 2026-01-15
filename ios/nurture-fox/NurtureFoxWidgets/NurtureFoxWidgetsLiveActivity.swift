import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

struct NurtureFoxLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { context in
            // --- LOCK SCREEN UI ---
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: 6)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(context.attributes.babyName) • Last Feed")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        
                        // Using context.state.startTime is correct
                        // We keep the .id() to ensure it treats it as a fresh timer
                        Text(context.state.startTime, style: .timer)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.primary)
                            .id(context.state.startTime)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "drop.fill")
                        .font(.title)
                        .foregroundStyle(.orange.gradient)
                        .padding(12)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            .activityBackgroundTint(Color.black.opacity(0.25))
            .activitySystemActionForegroundColor(.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "drop.fill").foregroundColor(.orange)
                        Text(context.attributes.babyName).font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("Last Feed").font(.caption).foregroundStyle(.secondary)
                        Text(context.state.startTime, style: .timer)
                            .font(.title2.bold())
                            .monospacedDigit()
                            .foregroundColor(.orange)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 15) {
                        Button(intent: LogDiaperIntent(type: "Pee")) { Label("Pee", systemImage: "drop") }.buttonStyle(.bordered).tint(.yellow)
                        Button(intent: LogDiaperIntent(type: "Poop")) { Label("Poop", systemImage: "brown.circle") }.buttonStyle(.bordered).tint(.brown)
                    }.padding(.top, 5)
                }
            } compactLeading: {
                Image(systemName: "drop.fill").foregroundColor(.orange)
            } compactTrailing: {
                Text(context.state.startTime, style: .timer).monospacedDigit().foregroundColor(.orange).frame(width: 45)
            } minimal: {
                Image(systemName: "drop.fill").foregroundColor(.orange)
            }
        }
    }
}
