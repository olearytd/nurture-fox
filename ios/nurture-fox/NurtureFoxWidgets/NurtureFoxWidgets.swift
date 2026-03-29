//
//  NurtureFoxWidgets.swift
//  NurtureFoxWidgets
//
//  Created by Tim OLeary on 1/13/26.
//

import WidgetKit
import SwiftUI
import CoreData

struct Provider: AppIntentTimelineProvider {
    private func fetchLastFeedDate() -> Date {
        let coreDataManager = CoreDataManager.shared
        let context = coreDataManager.container.viewContext

        let fetchRequest = BabyEventEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "type == %@", "FEED")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \BabyEventEntity.timestamp, ascending: false)]
        fetchRequest.fetchLimit = 1

        do {
            let events = try context.fetch(fetchRequest)
            return events.first?.timestamp ?? Date()
        } catch {
            print("Widget fetch error: \(error)")
            return Date()
        }
    }

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), lastFeedDate: Date(), configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let lastFeed = fetchLastFeedDate()
        return SimpleEntry(date: Date(), lastFeedDate: lastFeed, configuration: configuration)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let lastFeed = fetchLastFeedDate()

        let entry = SimpleEntry(date: Date(), lastFeedDate: lastFeed, configuration: configuration)

        // Refresh every 15 minutes to keep the data current
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let lastFeedDate: Date
    let configuration: ConfigurationAppIntent
}

struct NurtureFoxWidgetsEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular: // Watch Face Circle
            VStack(spacing: 0) {
                Image(systemName: "bottle.fill")
                    .font(.system(size: 10))
                Text(entry.lastFeedDate, style: .relative)
                    .font(.system(size: 12, weight: .bold))
                    .multilineTextAlignment(.center)
            }
        case .accessoryInline:
            Text("Last: \(entry.lastFeedDate, style: .relative) ago")
        default:
            VStack(alignment: .leading) {
                Label("Last Fed", systemImage: "timer")
                    .font(.headline)
                    .foregroundColor(.blue)

                Text(entry.lastFeedDate, style: .relative)
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("at \(entry.lastFeedDate.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct NurtureFoxWidgets: Widget {
    let kind: String = "NurtureFoxWidgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            NurtureFoxWidgetsEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        // Enable both iPhone Widgets and Watch Face Complications
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}
