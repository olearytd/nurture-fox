import SwiftUI
import SwiftData
import ActivityKit

struct TrackerView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Sort events to find the most recent one for the Status Card
    @Query(sort: \BabyEvent.timestamp, order: .reverse) private var recentEvents: [BabyEvent]
    
    @State private var amountText: String = ""
    @State private var isOz: Bool = true
    @State private var showDiaperSheet: Bool = false
    @State private var customTimestamp: Date? = nil
    @State private var showDatePicker: Bool = false
    @State private var showSettings = false
    
    @AppStorage("babyName") private var babyName: String = "Baby"
    
    var body: some View {
        NavigationStack {
            ScrollView { // Use ScrollView to ensure the card + form fit on smaller screens
                VStack(spacing: 24) {
                    Text("Nurture Fox")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    
                    // --- LAST FED STATUS CARD ---
                    if let lastFeed = recentEvents.first(where: { $0.type == "FEED" }) {
                        VStack(spacing: 8) {
                            Text("LAST FED")
                                .font(.caption.bold())
                                .opacity(0.7)
                            
                            Text(lastFeed.timestamp, style: .relative)
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                            
                            Text("\(lastFeed.amount, specifier: "%.1f") \(lastFeed.subtype) at \(lastFeed.timestamp.formatted(date: .omitted, time: .shortened))")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(Color.blue.gradient)
                        .foregroundColor(.white)
                        .cornerRadius(24)
                    }

                    // Date & Time Selection
                    HStack {
                        Text("Logging for:")
                            .foregroundStyle(.secondary)
                        
                        Button {
                            showDatePicker = true
                        } label: {
                            Text(customTimestamp?.formatted(date: .abbreviated, time: .shortened) ?? "Now")
                                .fontWeight(.bold)
                        }
                        
                        if customTimestamp != nil {
                            Button {
                                customTimestamp = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    // Amount Input
                    VStack(alignment: .leading) {
                        Text(isOz ? "Amount (oz)" : "Amount (ml)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("0.0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") {
                                        hideKeyboard()
                                    }
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Unit Switcher
                    Toggle(isOn: $isOz) {
                        Text(isOz ? "Ounces (oz)" : "Milliliters (ml)")
                    }
                    .fixedSize()
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button(action: logFeed) {
                            Label("Log Feed & Start Timer", systemImage: "timer")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: { showDiaperSheet = true }) {
                            Label("Log Diaper", systemImage: "drop.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                    }
                    .padding(.horizontal, 40)
                }
                .padding()
            }
            .onTapGesture { hideKeyboard() } // Dismiss keyboard on background tap
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    DatePicker("Select Date", selection: Binding(
                        get: { customTimestamp ?? Date() },
                        set: { customTimestamp = $0 }
                    ))
                    .datePickerStyle(.graphical)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showDatePicker = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .confirmationDialog("What type of diaper?", isPresented: $showDiaperSheet, titleVisibility: .visible) {
                Button("Pee") { logDiaper(subtype: "Pee") }
                Button("Poop") { logDiaper(subtype: "Poop") }
                Button("Both") { logDiaper(subtype: "Both") }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    // Logic Functions
    private func logFeed() {
        let amount = Float(amountText) ?? 0.0
        let timestamp = customTimestamp ?? Date()
        
        let newEvent = BabyEvent(
            type: "FEED",
            subtype: isOz ? "oz" : "ml",
            amount: amount,
            timestamp: timestamp
        )
        modelContext.insert(newEvent)
        
        // Success Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        startLiveActivity(startTime: timestamp)
        
        amountText = ""
        customTimestamp = nil
        hideKeyboard()
    }
    
    private func startLiveActivity(startTime: Date) {
        // 1. CLEANUP existing activities
        for activity in Activity<TimerAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        // 2. PROCEED with the 4-hour staleDate polish
        let attributes = TimerAttributes(babyName: babyName)
        let state = TimerAttributes.ContentState(startTime: startTime)
        
        // Step 3 Polish: Define when the activity becomes "Old"
        let staleDate = Calendar.current.date(byAdding: .hour, value: 4, to: startTime)
        let activityContent = ActivityContent(state: state, staleDate: staleDate)
        
        do {
            let _ = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )
            print("✅ New Activity Started with StaleDate")
        } catch {
            print("❌ Error: \(error.localizedDescription)")
        }
    }
    
    private func endAllLiveActivities() {
        Task {
            for activity in Activity<TimerAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    
    private func logDiaper(subtype: String) {
        let newEvent = BabyEvent(
            type: "DIAPER",
            subtype: subtype,
            amount: 0,
            timestamp: customTimestamp ?? Date()
        )
        modelContext.insert(newEvent)
        
        // Gentle haptic for diaper log
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        customTimestamp = nil
    }
}

extension View {

    func hideKeyboard() {

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

    }

}
