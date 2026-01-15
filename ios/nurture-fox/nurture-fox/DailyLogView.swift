import SwiftUI
import SwiftData

struct DailyLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BabyEvent.timestamp, order: .reverse) private var allEvents: [BabyEvent]
    
    @AppStorage("dailyOzGoal") private var dailyOzGoal: Double = 32.0
    @State private var showGoalEditor = false
    @State private var editingEvent: BabyEvent?
    
    // --- GROUPING LOGIC ---
    private var groupedEvents: [(Date, [BabyEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: allEvents) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var todayEvents: [BabyEvent] {
        let calendar = Calendar.current
        return allEvents.filter { calendar.isDateInToday($0.timestamp) }
    }
    
    var totalTodayOz: Float {
        calculateVolume(for: todayEvents)
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
                            Text("\(Int(totalTodayOz * 30)) ml")
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .bold()
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 5)
                }
                
                // --- DYNAMIC DATE SECTIONS ---
                ForEach(groupedEvents, id: \.0) { date, events in
                    Section {
                        ForEach(events) { event in
                            Button {
                                editingEvent = event
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(event.type == "FEED" ? "🍼 Feeding" : "💩 Diaper")
                                            .fontWeight(.bold)
                                            .foregroundColor(event.type == "FEED" ? .blue : .brown)
                                        
                                        if event.type == "FEED" {
                                            let ozValue = event.subtype == "oz" ? event.amount : event.amount / 30.0
                                            let mlValue = event.subtype == "ml" ? event.amount : event.amount * 30.0
                                            
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
                        .onDelete { offsets in
                            deleteItems(at: offsets, from: events)
                        }
                    } header: {
                        HStack {
                            Text(formatHeaderDate(date))
                            Spacer()
                            
                            // CALCULATE SUMMARY STATS
                            let dayTotalOz = calculateVolume(for: events)
                            let dayDiapers = events.filter { $0.type == "DIAPER" }.count
                            
                            HStack(spacing: 8) {
                                if dayTotalOz > 0 {
                                    Text("\(String(format: "%.1f", dayTotalOz)) oz")
                                }
                                
                                if dayTotalOz > 0 && dayDiapers > 0 {
                                    Text("•")
                                }
                                
                                if dayDiapers > 0 {
                                    Text("\(dayDiapers) \(dayDiapers == 1 ? "Diaper" : "Diapers")")
                                }
                            }
                            .font(.caption.bold())
                            .textCase(.none)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
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
    
    // --- HELPER FUNCTIONS ---

    private func calculateVolume(for events: [BabyEvent]) -> Float {
        events.filter { $0.type == "FEED" }.reduce(0) { sum, event in
            sum + (event.subtype == "ml" ? event.amount / 30.0 : event.amount)
        }
    }

    private func formatHeaderDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }
    }

    private func deleteItems(at offsets: IndexSet, from events: [BabyEvent]) {
        withAnimation {
            for index in offsets {
                let eventToDelete = events[index]
                modelContext.delete(eventToDelete)
            }
        }
    }
}
