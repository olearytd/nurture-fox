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

    private func getOzAmount(for event: BabyEvent) -> Float {
        if event.subtype == "ml" {
            return event.amount / 30.0 // Standardized rounding
        }
        return event.amount
    }

    private var baselineStats: (vol: Float, diapers: Float) {
        let calendar = Calendar.current
        let daysWithData = Set(allEvents.map { calendar.startOfDay(for: $0.timestamp) })
        let count = Float(max(1, daysWithData.count))
        let totalVol = feedingEvents.reduce(0) { $0 + getOzAmount(for: $1) }
        return (totalVol / count, Float(diaperEvents.count) / count)
    }

    private var averageInterval: String {
        let sortedFeeds = feedingEvents.sorted { $0.timestamp < $1.timestamp }
        guard sortedFeeds.count > 1 else { return "Log more feeds" }
        let totalHours = sortedFeeds.last!.timestamp.timeIntervalSince(sortedFeeds.first!.timestamp) / 3600
        return String(format: "%.1f hours", totalHours / Double(sortedFeeds.count - 1))
    }

    private func volSince(days: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let vol = feedingEvents.filter { $0.timestamp >= date }.reduce(0) { $0 + getOzAmount(for: $1) }
        return String(format: "%.0f oz", vol)
    }

    var last7DaysTotals: [DailyVolume] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).map { i -> DailyVolume in
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let total = feedingEvents.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }.reduce(0) { $0 + getOzAmount(for: $1) }
            return DailyVolume(date: date, volume: total)
        }.sorted { $0.date < $1.date }
    }

    // --- THE UI ---

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
                    allEvents: allEvents
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

    // FIXED: Renders a static snapshot to prevent infinite recursion
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
            allEvents: allEvents
        )
        .frame(width: 400) // Fixed width for better PDF/Image scaling
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

// 2. EXTRACTION: This prevents the crash by separating the UI from the Navigation/Toolbar
struct TrendsContentView: View {
    let todayEvents: [BabyEvent]
    let baselineStats: (vol: Float, diapers: Float)
    let last7DaysTotals: [DailyVolume]
    let feedingEvents: [BabyEvent]
    let diaperEvents: [BabyEvent]
    let averageInterval: String
    let volSince: (Int) -> String
    let getOzAmount: (BabyEvent) -> Float
    let allEvents: [BabyEvent]

    var body: some View {
        VStack(spacing: 20) {
            // 1. Baseline Comparison
            TrendSection(title: "7-Day Baseline Comparison") {
                let todayVol = todayEvents.reduce(0) { $0 + getOzAmount($1) }
                let volDiff = todayVol - baselineStats.vol
                
                TrendRow(label: "Vol Today", value: String(format: "%.1f oz", todayVol))
                TrendRow(label: "7-Day Avg", value: String(format: "%.1f oz", baselineStats.vol))
                
                Text("\(volDiff >= 0 ? "+" : "")\(String(format: "%.1f", volDiff)) oz vs baseline")
                    .font(.caption.bold())
                    .foregroundColor(volDiff >= 0 ? .green : .red)
                
                Divider().padding(.vertical, 5)
                
                let todayDiapers = Float(todayEvents.filter { $0.type == "DIAPER" }.count)
                let diaperDiff = todayDiapers - baselineStats.diapers
                TrendRow(label: "Diapers Today", value: "\(Int(todayDiapers))")
                TrendRow(label: "7-Day Avg", value: String(format: "%.1f", baselineStats.diapers))
                Text("\(diaperDiff >= 0 ? "+" : "")\(String(format: "%.1f", diaperDiff)) vs baseline")
                    .font(.caption.bold())
                    .foregroundColor(diaperDiff >= 0 ? .green : .red)
            }

            // 2. Volume Chart
            TrendSection(title: "Daily Volume (oz) - Last 7 Days") {
                Chart {
                    ForEach(last7DaysTotals) { day in
                        BarMark(
                            x: .value("Day", day.date, unit: .day),
                            y: .value("Volume", day.volume)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .cornerRadius(6)
                    }
                    RuleMark(y: .value("Avg", baselineStats.vol))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 200)
            }

            // 3. Historical Summary
            TrendSection(title: "Historical Summary") {
                TrendRow(label: "Last 7 Days Total", value: volSince(7))
                TrendRow(label: "Last 14 Days Total", value: volSince(14))
                TrendRow(label: "Last 30 Days Total", value: volSince(30))
            }

            // 4. Feeding Patterns
            TrendSection(title: "Feeding Patterns") {
                let dayCount = Float(max(1, Set(allEvents.map { Calendar.current.startOfDay(for: $0.timestamp) }).count))
                let totalOz = feedingEvents.reduce(0) { $0 + getOzAmount($1) }
                TrendRow(label: "Daily Average", value: String(format: "%.1f oz", totalOz / dayCount))
                TrendRow(label: "Bottles per Day", value: String(format: "%.1f", Float(feedingEvents.count) / dayCount))
                TrendRow(label: "Avg. per Bottle", value: String(format: "%.1f oz", totalOz / Float(max(1, feedingEvents.count))))
            }

            // 5. Diaper History
            TrendSection(title: "Diaper History") {
                TrendRow(label: "Total Changes", value: "\(diaperEvents.count)")
                TrendRow(label: "Total Pees", value: "\(diaperEvents.filter { $0.subtype.contains("Pee") || $0.subtype == "Both" }.count)")
                TrendRow(label: "Total Poops", value: "\(diaperEvents.filter { $0.subtype.contains("Poop") || $0.subtype == "Both" }.count)")
            }

            // 6. Intervals
            TrendSection(title: "Intervals") {
                TrendRow(label: "Avg. Time Between Feeds", value: averageInterval)
            }
        }
    }
}

// 3. SUPPORTING COMPONENTS
struct TrendSection<Content: View>: View {
    let title: String
    let content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline.bold()).foregroundColor(.blue)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct TrendRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
    }
}
