//
//  ContentView.swift
//  NurtureFoxWatch Watch App
//
//  Created by Tim OLeary on 1/14/26.
//

import SwiftUI
import SwiftData

struct WatchContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BabyEvent.timestamp, order: .reverse) private var recentEvents: [BabyEvent]
    
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
                    if let last = recentEvents.first(where: { $0.type == "FEED" }) {
                        VStack(alignment: .leading) {
                            Text(last.timestamp, style: .relative)
                                .font(.headline)
                                .foregroundColor(.blue)
                            
                            let mlAmount = last.subtype == "oz" ? last.amount * 30 : last.amount
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
        let event = BabyEvent(type: "FEED", subtype: "oz", amount: amount, timestamp: Date())
        modelContext.insert(event)
        WKInterfaceDevice.current().play(.success)
    }
    
    private func logDiaper(subtype: String = "Pee") {
        let event = BabyEvent(type: "DIAPER", subtype: subtype, amount: 0, timestamp: Date())
        modelContext.insert(event)
        WKInterfaceDevice.current().play(.click)
    }
}
