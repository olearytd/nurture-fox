//
//  TrendsView.swift
//  nurture-fox
//
//  Created by Tim OLeary on 1/9/26.
//


import SwiftUI
import SwiftData
import Charts

struct TrendsView: View {
    @Query(sort: \BabyEvent.timestamp, order: .forward) private var allEvents: [BabyEvent]
    
    // Computed property to group data for the chart
    var dailyTotals: [DailyVolume] {
        let calendar = Calendar.current
        let feeds = allEvents.filter { $0.type == "FEED" }
        
        // Group feeds by day and sum the amounts
        let grouped = Dictionary(grouping: feeds) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        
        return grouped.map { (date, events) in
            let total = events.reduce(0) { $0 + $1.amount }
            return DailyVolume(date: date, volume: total)
        }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Last 7 Days (oz)")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // The Chart Component
                    Chart {
                        ForEach(dailyTotals) { day in
                            BarMark(
                                x: .value("Day", day.date, unit: .day),
                                y: .value("Volume", day.volume)
                            )
                            .foregroundStyle(Color.blue.gradient)
                            .cornerRadius(4)
                        }
                    }
                    .frame(height: 250)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Stat Summary Cards
                    VStack(spacing: 12) {
                        StatCard(title: "Avg Daily Volume", value: "\(calculateAverage()) oz")
                        StatCard(title: "Total Feeds", value: "\(allEvents.filter { $0.type == "FEED" }.count)")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Trends")
        }
    }
    
    private func calculateAverage() -> String {
        guard !dailyTotals.isEmpty else { return "0" }
        let sum = dailyTotals.reduce(0) { $0 + $1.volume }
        return String(format: "%.1f", sum / Float(dailyTotals.count))
    }
}

// Simple data structure for the chart
struct DailyVolume: Identifiable {
    let id = UUID()
    let date: Date
    let volume: Float
}

// Reusable Stat Card component
struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
    }
}
