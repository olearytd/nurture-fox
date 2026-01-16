import SwiftUI
import SwiftData
import Charts

// 1. DATA STRUCTURE
struct DailyVolume: Identifiable {
    let id = UUID()
    let date: Date
    let volume: Float
}

struct TrendsView: View {
    @Query(sort: \BabyEvent.timestamp, order: .forward) private var allEvents: [BabyEvent]
    
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

    // Logic for the comparison section: Pro-rated by time and ignores empty days
    private var baselineStats: (vol: Float, diapers: Float, activeDays: Int) {
        let calendar = Calendar.current
        let now = Date()
        let currentComponents = calendar.dateComponents([.hour, .minute], from: now)
        
        var totalHistoricalVol: Float = 0
        var totalHistoricalDiapers: Float = 0
        var activeDaysCount: Int = 0
        
        let lookbackDays = 7
        
        for i in 1...lookbackDays {
            if let targetDate = calendar.date(byAdding: .day, value: -i, to: now) {
                let dayEvents = allEvents.filter { calendar.isDate($0.timestamp, inSameDayAs: targetDate) }
                
                if !dayEvents.isEmpty {
                    activeDaysCount += 1
                    let startOfDay = calendar.startOfDay(for: targetDate)
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

    // Milestones & Records Logic
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

    private func volSince(days: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let vol = feedingEvents.filter { $0.timestamp >= date }.reduce(0) { $0 + getOzAmount($1) }
        return String(format: "%.0f oz", vol)
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
                TrendsContentView(
                    todayEvents: todayEvents,
                    baselineStats: baselineStats,
                    last7DaysTotals: last7DaysTotals,
                    feedingEvents: feedingEvents,
                    diaperEvents: diaperEvents,
                    averageInterval: averageInterval,
                    volSince: volSince,
                    getOzAmount: getOzAmount,
                    allEvents: allEvents,
                    milestones: milestones
                )
                .padding()
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
            todayEvents: todayEvents,
            baselineStats: baselineStats,
            last7DaysTotals: last7DaysTotals,
            feedingEvents: feedingEvents,
            diaperEvents: diaperEvents,
            averageInterval: averageInterval,
            volSince: volSince,
            getOzAmount: getOzAmount,
            allEvents: allEvents,
            milestones: milestones
        )
        .frame(width: 400)
        .background(Color(.systemGroupedBackground))

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
    let todayEvents: [BabyEvent]
    let baselineStats: (vol: Float, diapers: Float, activeDays: Int)
    let last7DaysTotals: [DailyVolume]
    let feedingEvents: [BabyEvent]
    let diaperEvents: [BabyEvent]
    let averageInterval: String
    let volSince: (Int) -> String
    let getOzAmount: (BabyEvent) -> Float
    let allEvents: [BabyEvent]
    let milestones: (maxDayVol: Float, maxBottle: Float, longestStretch: Double)

    var body: some View {
        VStack(spacing: 20) {
            
            // 1. All-Time Records (Milestones)
            TrendSection(title: "All-Time Records") {
                HStack(spacing: 15) {
                    MilestoneCard(title: "Max Day", value: String(format: "%.1f", milestones.maxDayVol), unit: "oz", icon: "trophy.fill", color: .yellow)
                    MilestoneCard(title: "Big Bottle", value: String(format: "%.1f", milestones.maxBottle), unit: "oz", icon: "star.fill", color: .orange)
                }
                TrendRow(label: "Longest Feeding Gap", value: String(format: "%.1f hours", milestones.longestStretch))
            }

            // 2. Baseline Comparison
            TrendSection(title: "7-Day Baseline Comparison") {
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
                    Text("Based on \(baselineStats.activeDays) active days").font(.caption2).foregroundStyle(.secondary)
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
                    let dayCount = Float(max(1, baselineStats.activeDays))
                    let totalVol = feedingEvents.reduce(0) { $0 + getOzAmount($1) }
                    RuleMark(y: .value("Avg", totalVol / dayCount))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 180)
            }

            // 4. Historical Summary
            TrendSection(title: "Historical Summary") {
                TrendRow(label: "Last 7 Days Total", value: volSince(7))
                TrendRow(label: "Last 14 Days Total", value: volSince(14))
                TrendRow(label: "Last 30 Days Total", value: volSince(30))
            }

            // 5. Feeding Patterns
            TrendSection(title: "Feeding Patterns") {
                let dayCount = Float(max(1, baselineStats.activeDays))
                let totalOz = feedingEvents.reduce(0) { $0 + getOzAmount($1) }
                TrendRow(label: "Daily Average", value: String(format: "%.1f oz", totalOz / dayCount))
                TrendRow(label: "Bottles per Day", value: String(format: "%.1f", Float(feedingEvents.count) / dayCount))
                TrendRow(label: "Avg. per Bottle", value: String(format: "%.1f oz", totalOz / Float(max(1, feedingEvents.count))))
            }

            // 6. Diaper History
            TrendSection(title: "Diaper History") {
                TrendRow(label: "Total Changes", value: "\(diaperEvents.count)")
                TrendRow(label: "Total Pees", value: "\(diaperEvents.filter { $0.subtype.contains("Pee") || $0.subtype == "Both" }.count)")
                TrendRow(label: "Total Poops", value: "\(diaperEvents.filter { $0.subtype.contains("Poop") || $0.subtype == "Both" }.count)")
            }

            // 7. Intervals
            TrendSection(title: "Intervals") {
                TrendRow(label: "Avg. Time Between Feeds", value: averageInterval)
            }
        }
    }
}

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
