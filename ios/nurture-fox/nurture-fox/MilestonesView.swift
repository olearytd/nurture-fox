//
//  MilestonesView.swift
//  nurture-fox
//
//  Created by Tim OLeary on 1/9/26.
//


import SwiftUI
import SwiftData

struct MilestonesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Milestone.timestamp, order: .reverse) private var milestones: [Milestone]
    
    // You would pull this from your Settings/UserDefaults
    let babyBirthDate: Date = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    
    let options = [
        "First Smile", "First Laugh", "Rolling Over", "Sitting Up",
        "First Solid Food", "Crawling", "First Word", "First Steps"
    ]
    
    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("What happened recently?")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // The Grid of Buttons
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(options, id: \.self) { option in
                            Button {
                                addMilestone(name: option)
                            } label: {
                                Text(option)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.accentColor.opacity(0.1))
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider().padding(.vertical)
                    
                    Text("Memory Book")
                        .font(.title2.bold())
                        .padding(.horizontal)
                    
                    // Milestone List
                    if milestones.isEmpty {
                        ContentUnavailableView("No Memories Yet", systemImage: "star", description: Text("Tap a milestone above to save a memory."))
                    } else {
                        ForEach(milestones) { milestone in
                            HStack {
                                Image(systemName: "star.circle.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.title)
                                
                                VStack(alignment: .leading) {
                                    Text(milestone.name)
                                        .font(.headline)
                                    Text("Accomplished at: \(milestone.ageAtOccurrence)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(role: .destructive) {
                                    modelContext.delete(milestone)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Milestones")
        }
    }
    
    private func addMilestone(name: String) {
        let age = calculateAge(from: babyBirthDate, to: Date())
        let newMilestone = Milestone(name: name, timestamp: Date(), ageAtOccurrence: age)
        modelContext.insert(newMilestone)
    }
    
    private func calculateAge(from: Date, to: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: from, to: to)
        let years = components.year ?? 0
        let months = components.month ?? 0
        let days = components.day ?? 0
        
        var ageString = ""
        if years > 0 { ageString += "\(years)y " }
        if months > 0 { ageString += "\(months)m " }
        ageString += "\(days)d"
        return ageString
    }
}
