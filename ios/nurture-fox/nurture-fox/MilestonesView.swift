import SwiftUI
import SwiftData

struct MilestonesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Milestone.timestamp, order: .reverse) private var milestones: [Milestone]
    
    // Links to your global baby birthday setting
    @AppStorage("babyBirthday") private var babyBirthday: Double = Date().timeIntervalSince1970
    
    // Expanded options to match your Android list
    let options = [
        "First Smile", "First Laugh", "Rolling Over", "Sitting Up",
        "First Solid Food", "Crawling", "First Word", "First Steps",
        "Waving Bye-Bye", "Pulling to Stand", "First Tooth", "Walking"
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
                        // Using a VStack instead of a List inside a ScrollView to avoid layout conflicts
                        VStack(spacing: 12) {
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
                                            .foregroundStyle(.red)
                                    }
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Milestones")
        }
    }
    
    private func addMilestone(name: String) {
        let birthDate = Date(timeIntervalSince1970: babyBirthday)
        let age = calculateAge(from: birthDate, to: Date())
        
        let newMilestone = Milestone(
            name: name,
            timestamp: Date(),
            ageAtOccurrence: age
        )
        
        modelContext.insert(newMilestone)
        
        // Haptic feedback for a developmental win!
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func calculateAge(from: Date, to: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: from, to: to)
        let years = components.year ?? 0
        let months = components.month ?? 0
        let days = components.day ?? 0
        
        var ageString = ""
        if years > 0 { ageString += "\(years)y " }
        if months > 0 { ageString += "\(months)m " }
        // Ensure we always show days, even if 0, for "Just Born" accuracy
        ageString += "\(days)d"
        
        return ageString.isEmpty ? "0d" : ageString
    }
}
