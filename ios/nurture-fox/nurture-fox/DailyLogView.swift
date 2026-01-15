import SwiftUI
import SwiftData

struct DailyLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BabyEvent.timestamp, order: .reverse) private var allEvents: [BabyEvent]
    
    // Goal Settings
    @AppStorage("dailyOzGoal") private var dailyOzGoal: Double = 32.0
    @State private var showGoalEditor = false
    
    // Editing State
    @State private var editingEvent: BabyEvent?
    
    // Filter for "Today" (00:00 to 23:59)
    var todayEvents: [BabyEvent] {
        let calendar = Calendar.current
        return allEvents.filter { calendar.isDateInToday($0.timestamp) }
    }
    
    // Standardized Math: 1 oz = 30 ml
    var totalTodayOz: Float {
        todayEvents.filter { $0.type == "FEED" }.reduce(0) { sum, event in
            // Standardized conversion: ml / 30
            sum + (event.subtype == "ml" ? event.amount / 30.0 : event.amount)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // --- GOALS SECTION ---
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Daily Goal")
                                .font(.headline)
                            Spacer()
                            Button("\(Int(dailyOzGoal)) oz") {
                                showGoalEditor = true
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        }
                        
                        let progress = CGFloat(totalTodayOz) / CGFloat(dailyOzGoal)
                        
                        ProgressView(value: min(progress, 1.0))
                            .tint(progress >= 1.0 ? .green : .blue)
                        
                        HStack {
                            Text("\(String(format: "%.1f", totalTodayOz)) oz")
                            Text("/")
                                .foregroundStyle(.secondary)
                            // Standardized conversion: oz * 30
                            Text("\(Int(totalTodayOz * 30)) ml")
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .bold()
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 5)
                }
                
                // --- LOG ENTRIES ---
                ForEach(allEvents) { event in
                    Button {
                        editingEvent = event
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(event.type == "FEED" ? "🍼 Feeding" : "💩 Diaper")
                                    .fontWeight(.bold)
                                    .foregroundColor(event.type == "FEED" ? .blue : .brown)
                                
                                if event.type == "FEED" {
                                    // Calculate standard oz/ml display
                                    let ozValue = event.subtype == "oz" ? event.amount : event.amount / 30.0
                                    let mlValue = event.subtype == "ml" ? event.amount : event.amount * 30.0
                                    
                                    // Displays clean "oz / ml" format as per 12:51 screenshot
                                    Text("\(String(format: "%.1f", ozValue)) oz / \(Int(mlValue)) ml")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(event.subtype)
                                        .font(.subheadline)
                                }
                            }
                            
                            Spacer()
                            
                            Text(event.timestamp, style: .time)
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Daily Log")
            .sheet(item: $editingEvent) { event in
                EditEventView(event: event)
            }
            .alert("Set Daily Goal (oz)", isPresented: $showGoalEditor) {
                TextField("Goal", value: $dailyOzGoal, format: .number)
                    .keyboardType(.decimalPad)
                Button("Save", action: {})
                Button("Cancel", role: .cancel, action: {})
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(allEvents[index])
            }
        }
    }
}
