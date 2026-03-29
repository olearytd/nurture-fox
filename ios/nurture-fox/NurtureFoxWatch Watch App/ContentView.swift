//
//  ContentView.swift
//  NurtureFoxWatch Watch App
//
//  Created by Tim OLeary on 1/14/26.
//

import SwiftUI
import CoreData
import WatchKit

struct WatchContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BabyEventEntity.timestamp, ascending: false)],
        animation: .default)
    private var recentEvents: FetchedResults<BabyEventEntity>

    @State private var showDiaperOptions = false

    var body: some View {
        NavigationStack {
            List {
                Section("Quick Log") {
                    HStack(spacing: 10) {
                        Button("3oz") { logQuickFeed(amount: 3) }
                            .buttonStyle(.borderedProminent)
                        Button("4oz") { logQuickFeed(amount: 4) }
                            .buttonStyle(.borderedProminent)
                    }

                    // Tap to open options, matches the Android "Action Sheet" feel
                    Button {
                        showDiaperOptions = true
                    } label: {
                        Label("Diaper...", systemImage: "drop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.brown)
                    .buttonStyle(.bordered)
                }

                Section("Last Feed") {
                    if let last = recentEvents.first(where: { ($0.type ?? "FEED") == "FEED" }) {
                        VStack(alignment: .leading) {
                            Text(last.timestamp ?? Date(), style: .relative)
                                .font(.headline)
                                .foregroundColor(.blue)

                            let subtype = last.subtype ?? "oz"
                            let mlAmount = subtype == "oz" ? last.amount * 30 : last.amount
                            Text("\(last.amount, specifier: "%.1f") oz / \(Int(mlAmount)) ml")
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Fox")
            .confirmationDialog("Diaper Type", isPresented: $showDiaperOptions) {
                Button("Pee") { logDiaper(subtype: "Pee") }
                Button("Poop") { logDiaper(subtype: "Poop") }
                Button("Both") { logDiaper(subtype: "Both") }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    private func logQuickFeed(amount: Float) {
        let event = BabyEventEntity(context: viewContext)
        event.id = UUID()
        event.type = "FEED"
        event.subtype = "oz"
        event.amount = amount
        event.timestamp = Date()

        do {
            try viewContext.save()
            WKInterfaceDevice.current().play(.success)
        } catch {
            print("Error saving feed: \(error)")
        }
    }

    private func logDiaper(subtype: String = "Pee") {
        let event = BabyEventEntity(context: viewContext)
        event.id = UUID()
        event.type = "DIAPER"
        event.subtype = subtype
        event.amount = 0
        event.timestamp = Date()

        do {
            try viewContext.save()
            WKInterfaceDevice.current().play(.click)
        } catch {
            print("Error saving diaper: \(error)")
        }
    }
}
