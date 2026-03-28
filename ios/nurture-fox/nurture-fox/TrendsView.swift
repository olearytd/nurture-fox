import SwiftUI
import SwiftData
import Charts

// 1. DATA STRUCTURE
struct DailyVolume: Identifiable {
    let id = UUID()
    let date: Date
    let volume: Float
}

enum TrendWindow: String, CaseIterable, Identifiable {
    case last7 = "7 Days"
    case weekly = "Weekly"
    var id: Self { self }
}

struct TrendsView: View {
    @Query(sort: \BabyEvent.timestamp, order: .forward) private var allEvents: [BabyEvent]
    @State private var selectedWindow: TrendWindow = .last7

    // --- THE BRAIN (Computed Properties) ---

    private var feedingEvents: [BabyEvent] { allEvents.filter { $0.type == "FEED" } }
    private var diaperEvents: [BabyEvent] { allEvents.filter { $0.type == "DIAPER" } }
    private var todayEvents: [BabyEvent] { allEvents.filter { Calendar.current.isDateInToday($0.timestamp) } }

    private func getOzAmount(_ event: BabyEvent) -> Float {
        if event.subtype == "ml" {
            return event.amount / 30.0
        }
        return event.amount
    }

    // New: Calculate total days used in the app
    private var totalActiveDays: Int {
        let calendar = Calendar.current
        let dates = Set(allEvents.map { calendar.startOfDay(for: $0.timestamp) })
        return max(1, dates.count)
    }

    // Logic for comparison: Pro-rated by time
    private var baselineStats: (vol: Float, diapers: Float, activeDays: Int) {
        let calendar = Calendar.current
        let now = Date()
        let currentComponents = calendar.dateComponents([.hour, .minute], from: now)
        var totalHistoricalVol: Float = 0
        var totalHistoricalDiapers: Float = 0
        var activeDaysCount: Int = 0

        for i in 1...7 {
            if let targetDate = calendar.date(byAdding: .day, value: -i, to: now) {
                let dayEvents = allEvents.filter { calendar.isDate($0.timestamp, inSameDayAs: targetDate) }
                if !dayEvents.isEmpty {
                    activeDaysCount += 1
                    let cutoffDate = calendar.date(bySettingHour: currentComponents.hour ?? 23,
                                                 minute: currentComponents.minute ?? 59,
                                                 second: 0,
                                                 of: targetDate) ?? targetDate

                    let dayFeeds = dayEvents.filter { $0.type == "FEED" && $0.timestamp <= cutoffDate }
                    let dayDiapers = dayEvents.filter { $0.type == "DIAPER" && $0.timestamp <= cutoffDate }
                    totalHistoricalVol += dayFeeds.reduce(0) { $0 + getOzAmount($1) }
                    totalHistoricalDiapers += Float(dayDiapers.count)
                }
            }
        }
        let denominator = Float(max(1, activeDaysCount))
        return (totalHistoricalVol / denominator, totalHistoricalDiapers / denominator, activeDaysCount)
    }

    private var milestones: (maxDayVol: Float, maxBottle: Float, longestStretch: Double) {
        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: feedingEvents) { calendar.startOfDay(for: $0.timestamp) }
        let dailyTotals = groupedByDay.values.map { $0.reduce(0) { $0 + getOzAmount($1) } }
        let maxDay = dailyTotals.max() ?? 0
        let maxBottle = feedingEvents.map { getOzAmount($0) }.max() ?? 0
        var maxStretch: Double = 0
        let sortedFeeds = feedingEvents.sorted { $0.timestamp < $1.timestamp }
        if sortedFeeds.count > 1 {
            for i in 0..<sortedFeeds.count - 1 {
                let diff = sortedFeeds[i+1].timestamp.timeIntervalSince(sortedFeeds[i].timestamp) / 3600
                if diff > maxStretch { maxStretch = diff }
            }
        }
        return (maxDay, maxBottle, maxStretch)
    }

    private var averageInterval: String {
        let sortedFeeds = feedingEvents.sorted { $0.timestamp < $1.timestamp }
        guard sortedFeeds.count > 1 else { return "Log more feeds" }
        let totalHours = sortedFeeds.last!.timestamp.timeIntervalSince(sortedFeeds.first!.timestamp) / 3600
        return String(format: "%.1f hours", totalHours / Double(sortedFeeds.count - 1))
    }

    var last7DaysTotals: [DailyVolume] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).map { i -> DailyVolume in
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let total = feedingEvents.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }.reduce(0) { $0 + getOzAmount($1) }
            return DailyVolume(date: date, volume: total)
        }.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // NEW: Toggle Switcher
                    Picker("Time Window", selection: $selectedWindow) {
                        ForEach(TrendWindow.allCases) { window in
                            Text(window.rawValue).tag(window)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    TrendsContentView(
                        selectedWindow: selectedWindow,
                        todayEvents: todayEvents,
                        baselineStats: baselineStats,
                        last7DaysTotals: last7DaysTotals,
                        feedingEvents: feedingEvents,
                        diaperEvents: diaperEvents,
                        averageInterval: averageInterval,
                        allEvents: allEvents,
                        milestones: milestones,
                        totalActiveDays: totalActiveDays,
                        getOzAmount: getOzAmount
                    )
                    .padding()
                }
            }
            .navigationTitle("Trends")
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: renderTrendsToImage()) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    @MainActor
    private func renderTrendsToImage() -> URL {
        let shareView = TrendsContentView(
            selectedWindow: selectedWindow,
            todayEvents: todayEvents,
            baselineStats: baselineStats,
            last7DaysTotals: last7DaysTotals,
            feedingEvents: feedingEvents,
            diaperEvents: diaperEvents,
            averageInterval: averageInterval,
            allEvents: allEvents,
            milestones: milestones,
            totalActiveDays: totalActiveDays,
            getOzAmount: getOzAmount
        ).frame(width: 400).background(Color(.systemGroupedBackground))

        let renderer = ImageRenderer(content: shareView)
        renderer.scale = 3.0
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("NurtureFox_Trends.png")
        if let image = renderer.uiImage, let data = image.pngData() {
            try? data.write(to: url)
        }
        return url
    }
}

struct TrendsContentView: View {
    let selectedWindow: TrendWindow
    let todayEvents: [BabyEvent]
    let baselineStats: (vol: Float, diapers: Float, activeDays: Int)
    let last7DaysTotals: [DailyVolume]
    let feedingEvents: [BabyEvent]
    let diaperEvents: [BabyEvent]
    let averageInterval: String
    let allEvents: [BabyEvent]
    let milestones: (maxDayVol: Float, maxBottle: Float, longestStretch: Double)
    let totalActiveDays: Int
    let getOzAmount: (BabyEvent) -> Float

    // Dynamic Logic based on toggle
    private var filteredFeedingEvents: [BabyEvent] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return feedingEvents.filter { $0.timestamp >= cutoff }
    }

    private var currentDayCount: Float {
        7.0
    }

    var body: some View {
        if selectedWindow == .weekly {
            WeeklyCalendarView(allEvents: allEvents)
        } else {
            VStack(spacing: 20) {

            // 1. All-Time Records (Always all-time)
            TrendSection(title: "All-Time Records") {
                HStack(spacing: 15) {
                    MilestoneCard(title: "Max Day", value: String(format: "%.1f", milestones.maxDayVol), unit: "oz", icon: "trophy.fill", color: .yellow)
                    MilestoneCard(title: "Big Bottle", value: String(format: "%.1f", milestones.maxBottle), unit: "oz", icon: "star.fill", color: .orange)
                }
                TrendRow(label: "Longest Feeding Gap", value: String(format: "%.1f hours", milestones.longestStretch))
            }

            // 2. Baseline Comparison
            TrendSection(title: "Today vs Baseline") {
                let todayVol = todayEvents.reduce(0) { $0 + getOzAmount($1) }
                let volDiff = todayVol - baselineStats.vol
                TrendRow(label: "Vol Today", value: String(format: "%.1f oz", todayVol))
                TrendRow(label: "Avg (to this time)", value: String(format: "%.1f oz", baselineStats.vol))
                Text("\(volDiff >= 0 ? "+" : "")\(String(format: "%.1f", volDiff)) oz vs baseline")
                    .font(.caption.bold())
                    .foregroundColor(volDiff >= 0 ? .green : .red)

                Divider().padding(.vertical, 5)

                let todayDiapers = Float(todayEvents.filter { $0.type == "DIAPER" }.count)
                let diaperDiff = todayDiapers - baselineStats.diapers
                TrendRow(label: "Diapers Today", value: "\(Int(todayDiapers))")
                TrendRow(label: "Avg (to this time)", value: String(format: "%.1f", baselineStats.diapers))
                HStack {
                    Text("\(diaperDiff >= 0 ? "+" : "")\(String(format: "%.1f", diaperDiff)) vs baseline")
                        .font(.caption.bold())
                        .foregroundColor(diaperDiff >= 0 ? .green : .red)
                    Spacer()
                    Text("Based on \(baselineStats.activeDays) days").font(.caption2).foregroundStyle(.secondary)
                }
            }

            // 3. Volume Chart
            TrendSection(title: "Daily Volume (oz) - Last 7 Days") {
                Chart {
                    ForEach(last7DaysTotals) { day in
                        BarMark(x: .value("Day", day.date, unit: .day), y: .value("Volume", day.volume))
                            .foregroundStyle(Color.blue.gradient)
                            .cornerRadius(6)
                    }
                    // The line always reflects the selected window's average
                    let totalOz = filteredFeedingEvents.reduce(0) { $0 + getOzAmount($1) }
                    RuleMark(y: .value("Avg", totalOz / currentDayCount))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 180)
            }

            // 4. Feeding Patterns (FIXED MATH)
            TrendSection(title: "Feeding Patterns (\(selectedWindow.rawValue))") {
                let totalOz = filteredFeedingEvents.reduce(0) { $0 + getOzAmount($1) }
                let bottleCount = filteredFeedingEvents.count

                TrendRow(label: "Daily Average", value: String(format: "%.1f oz", totalOz / currentDayCount))
                TrendRow(label: "Bottles per Day", value: String(format: "%.1f", Float(bottleCount) / currentDayCount))
                TrendRow(label: "Avg. per Bottle", value: String(format: "%.1f oz", totalOz / Float(max(1, bottleCount))))
            }

            // 5. Historical Summary
            TrendSection(title: "Historical Totals") {
                let totalOz = feedingEvents.reduce(0) { $0 + getOzAmount($1) }
                TrendRow(label: "All-Time Volume", value: String(format: "%.0f oz", totalOz))
                TrendRow(label: "All-Time Diapers", value: "\(diaperEvents.count)")
                TrendRow(label: "Days Active", value: "\(totalActiveDays)")
            }

            TrendSection(title: "Intervals") {
                TrendRow(label: "Avg. Time Between Feeds", value: averageInterval)
            }
            }
        }
    }
}
// ... [Remaining UI components MilestoneCard, TrendSection, TrendRow stay the same]

struct MilestoneCard: View {
    let title: String; let value: String; let unit: String; let icon: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(.caption2.bold()).foregroundColor(color)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value).font(.title3.bold())
                Text(unit).font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1)).cornerRadius(12)
    }
}

struct TrendSection<Content: View>: View {
    let title: String; let content: Content
    init(title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline.bold()).foregroundColor(.blue)
            content
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground)).cornerRadius(16)
    }
}

struct TrendRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
    }
}

// MARK: - Weekly Calendar View
struct WeeklyCalendarView: View {
    let allEvents: [BabyEvent]
    @State private var selectedEvent: BabyEvent?

    // Get events for the current week (Sunday - Saturday)
    private var weekEvents: [BabyEvent] {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

        return allEvents.filter { $0.timestamp >= weekStart && $0.timestamp < weekEnd }
    }

    private var weekDays: [Date] {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }

        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with day names
                HStack(spacing: 0) {
                    ForEach(weekDays, id: \.self) { day in
                        VStack(spacing: 4) {
                            Text(day, format: .dateTime.weekday(.abbreviated))
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Text(day, format: .dateTime.day())
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))

                // Timeline grid
                GeometryReader { geometry in
                    let totalWidth = geometry.size.width
                    let timeColumnWidth: CGFloat = 44
                    let calendarWidth = totalWidth - timeColumnWidth
                    let dayWidth = calendarWidth / 7
                    let hourHeight: CGFloat = 60

                    ZStack(alignment: .topLeading) {
                        // Grid lines
                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                HStack(spacing: 0) {
                                    // Time label
                                    Text(formatHour(hour))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .frame(width: 40, alignment: .trailing)
                                        .padding(.trailing, 4)

                                    // Grid line
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 1)
                                }
                                .frame(height: hourHeight)
                            }
                        }

                        // Vertical day separators
                        HStack(spacing: 0) {
                            Spacer().frame(width: timeColumnWidth)
                            ForEach(0..<7, id: \.self) { dayIndex in
                                Color.clear
                                    .frame(width: dayWidth)
                                    .overlay(
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 1),
                                        alignment: .leading
                                    )
                            }
                        }

                        // Events - grouped by day and time slot
                        ForEach(Array(groupEventsByDayAndTime().enumerated()), id: \.offset) { _, group in
                            ForEach(Array(group.events.enumerated()), id: \.element.id) { index, event in
                                EventRectangle(
                                    event: event,
                                    weekDays: weekDays,
                                    dayWidth: dayWidth,
                                    hourHeight: hourHeight,
                                    horizontalIndex: index,
                                    totalInSlot: group.events.count,
                                    timeColumnWidth: timeColumnWidth
                                )
                                .onTapGesture {
                                    selectedEvent = event
                                }
                            }
                        }
                    }
                }
                .frame(height: 60 * 24) // 24 hours * 60 points per hour
                .padding(.leading, 0)
            }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: $selectedEvent) { event in
            EventDetailSheet(event: event)
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        return date.formatted(date: .omitted, time: .shortened)
    }

    // Group events by day and 15-minute time slot
    private func groupEventsByDayAndTime() -> [EventGroup] {
        let calendar = Calendar.current
        var groups: [String: [BabyEvent]] = [:]

        for event in weekEvents {
            let dayStart = calendar.startOfDay(for: event.timestamp)
            let components = calendar.dateComponents([.hour, .minute], from: event.timestamp)
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0
            let timeSlot = hour * 60 + (minute / 15) * 15 // Round to 15-min slots

            let key = "\(dayStart.timeIntervalSince1970)-\(timeSlot)"
            groups[key, default: []].append(event)
        }

        return groups.map { EventGroup(key: $0.key, events: $0.value) }
    }
}

struct EventGroup {
    let key: String
    let events: [BabyEvent]
}

struct EventRectangle: View {
    let event: BabyEvent
    let weekDays: [Date]
    let dayWidth: CGFloat
    let hourHeight: CGFloat
    let horizontalIndex: Int
    let totalInSlot: Int
    let timeColumnWidth: CGFloat

    var body: some View {
        let calendar = Calendar.current
        let eventDay = calendar.startOfDay(for: event.timestamp)

        if let dayIndex = weekDays.firstIndex(where: { calendar.isDate($0, inSameDayAs: eventDay) }) {
            let components = calendar.dateComponents([.hour, .minute], from: event.timestamp)
            let hour = CGFloat(components.hour ?? 0)
            let minute = CGFloat(components.minute ?? 0)
            let yPosition = (hour + minute / 60.0) * hourHeight

            // Calculate pill width - divide day column width by number of simultaneous events
            let padding: CGFloat = 4
            let availableWidth = dayWidth - (padding * 2)
            let pillWidth: CGFloat = min(availableWidth / CGFloat(totalInSlot) - 2, 50)

            // Calculate X position: time column + (day index * day width) + padding + (horizontal index * pill width)
            let dayColumnStart = timeColumnWidth + (CGFloat(dayIndex) * dayWidth)
            let xPosition = dayColumnStart + padding + (CGFloat(horizontalIndex) * (pillWidth + 2))

            RoundedRectangle(cornerRadius: 10)
                .fill(eventColor)
                .frame(width: pillWidth, height: 20)
                .overlay(
                    HStack(spacing: 2) {
                        Text(eventIcon)
                            .font(.system(size: 12))
                        if event.type == "FEED" && pillWidth > 35 {
                            Text("\(String(format: "%.0f", event.subtype == "oz" ? event.amount : event.amount / 30.0))")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                )
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                .offset(x: xPosition, y: yPosition)
        }
    }

    private var eventColor: Color {
        if event.type == "FEED" {
            return .blue
        } else {
            switch event.subtype {
            case "Pee": return .yellow
            case "Poop": return .brown
            case "Both": return .orange
            default: return .gray
            }
        }
    }

    private var eventIcon: String {
        if event.type == "FEED" {
            return "🍼"
        } else {
            switch event.subtype {
            case "Pee": return "💧"
            case "Poop": return "💩"
            case "Both": return "💦"
            default: return "🔹"
            }
        }
    }
}

struct EventDetailSheet: View {
    let event: BabyEvent
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Type")
                            .foregroundColor(.secondary)
                        Spacer()
                        if event.type == "FEED" {
                            Text("🍼 Feeding")
                                .fontWeight(.semibold)
                        } else {
                            let emoji = event.subtype == "Pee" ? "💧" : event.subtype == "Poop" ? "💩" : "💦"
                            Text("\(emoji) \(event.subtype) Diaper")
                                .fontWeight(.semibold)
                        }
                    }

                    HStack {
                        Text("Time")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(event.timestamp, format: .dateTime.hour().minute())
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("Date")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(event.timestamp, format: .dateTime.month().day().year())
                            .fontWeight(.semibold)
                    }

                    if event.type == "FEED" {
                        HStack {
                            Text("Amount")
                                .foregroundColor(.secondary)
                            Spacer()
                            let ozValue = event.subtype == "oz" ? event.amount : event.amount / 30.0
                            let mlValue = event.subtype == "ml" ? event.amount : event.amount * 30.0
                            Text("\(String(format: "%.1f", ozValue)) oz / \(Int(mlValue)) ml")
                                .fontWeight(.semibold)
                        }
                    }

                    if let note = event.note, !note.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Note")
                                .foregroundColor(.secondary)
                            Text(note)
                                .fontWeight(.semibold)
                        }
                    }
                }

                Section {
                    Button {
                        showEditSheet = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Edit Event")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditEventView(event: event)
            }
        }
    }
}
