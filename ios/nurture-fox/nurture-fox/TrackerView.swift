import SwiftUI
import SwiftData
import ActivityKit
import Combine
import CoreData

struct TrackerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var coreDataManager: CoreDataManager
    @EnvironmentObject private var cloudSettings: CloudSettings
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BabyEventEntity.timestamp, ascending: false)],
        animation: .default)
    private var recentEvents: FetchedResults<BabyEventEntity>

    @State private var amountText: String = ""
    @State private var isOz: Bool = true
    @State private var showDiaperSheet: Bool = false
    @State private var customTimestamp: Date? = nil
    @State private var showDatePicker: Bool = false
    @State private var showSettings = false

    // Toast States
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    // Live Activity State
    @State private var isLiveActivityRunning: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Nurture Fox")
                        .font(.system(size: 34, weight: .bold, design: .rounded))

                    // --- LAST FED STATUS CARD ---
                    if let lastFeed = recentEvents.first(where: { $0.type == "FEED" }) {
                        let feedTimestamp = lastFeed.timestamp ?? Date()
                        let feedAmount = lastFeed.amount ?? 0.0
                        let feedSubtype = lastFeed.subtype ?? "oz"

                        VStack(spacing: 8) {
                            Text("LAST FED")
                                .font(.caption.bold())
                                .opacity(0.7)

                            Text(feedTimestamp, style: .relative)
                                .font(.system(size: 40, weight: .bold, design: .rounded))

                            Text("\(feedAmount, specifier: "%.1f") \(feedSubtype) at \(feedTimestamp.formatted(date: .omitted, time: .shortened))")
                                .font(.subheadline)

                            if abs(feedTimestamp.timeIntervalSinceNow) < 28800 {
                                if isLiveActivityRunning {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Live Activity Active")
                                    }
                                    .font(.caption.bold())
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(.white)
                                    .cornerRadius(20)
                                    .padding(.top, 10)
                                } else {
                                    Button {
                                        startLiveActivity(startTime: feedTimestamp)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "play.circle.fill")
                                            Text("Restart Live Activity")
                                        }
                                        .font(.caption.bold())
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(.white)
                                        .cornerRadius(20)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 10)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(Color.blue.gradient)
                        .foregroundColor(.white)
                        .cornerRadius(24)
                    }

                    // --- DATE & TIME SELECTION ---
                    HStack(spacing: 12) {
                        Label("Logging for:", systemImage: "clock.badge.checkmark")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)

                        Button {
                            showDatePicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(customTimestamp?.formatted(date: .abbreviated, time: .shortened) ?? "Now")
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(customTimestamp == nil ? Color.gray.opacity(0.1) : Color.blue.opacity(0.1))
                                    .cornerRadius(8)

                                if customTimestamp != nil {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                }
                            }
                        }

                        if customTimestamp != nil {
                            Button {
                                customTimestamp = nil
                            } label: {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.title3)
                            }
                        }
                    }
                    .padding(.bottom, 8)

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
                                    Button("Done") { hideKeyboard() }
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

                    // --- RECENT LOGS SECTION ---
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Logs")
                            .font(.headline)
                            .padding(.top)

                        ForEach(recentEvents.prefix(5)) { event in
                            HStack {
                                if event.type ?? "FEED" == "FEED" {
                                    Image(systemName: "mouth.fill")
                                        .foregroundStyle(.blue)
                                } else {
                                    // Custom emoji for each diaper type
                                    let subtype = event.subtype ?? "Pee"
                                    let diaperEmoji = subtype == "Pee" ? "💧" : subtype == "Poop" ? "💩" : "💦"
                                    Text(diaperEmoji)
                                        .font(.title3)
                                }

                                VStack(alignment: .leading) {
                                    let type = event.type ?? "FEED"
                                    let subtype = event.subtype ?? "oz"
                                    Text(type == "FEED" ? "Feed: \(event.amount, specifier: "%.1f") \(subtype)" : "Diaper: \(subtype)")
                                        .font(.subheadline.bold())
                                    Text((event.timestamp ?? Date()).formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if let timestamp = event.timestamp, event.type ?? "FEED" == "FEED" && abs(timestamp.timeIntervalSinceNow) < 28800 {
                                    Button {
                                        startLiveActivity(startTime: timestamp)
                                    } label: {
                                        Image(systemName: "play.circle")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .onTapGesture { hideKeyboard() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            // --- SYNC LISTENERS ---
            .onAppear {
                checkLiveActivityStatus()
                refreshTimerIfNecessary()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    checkLiveActivityStatus()
                    refreshTimerIfNecessary()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
                refreshTimerIfNecessary()
            }
            .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
                checkLiveActivityStatus()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(coreDataManager)
                    .environmentObject(cloudSettings)
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    List {
                        Section {
                            HStack {
                                Text("Time")
                                Spacer()
                                DatePicker(
                                    "Select Time",
                                    selection: Binding(
                                        get: { customTimestamp ?? Date() },
                                        set: { customTimestamp = $0 }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                            }
                        } footer: {
                            Text("Adjust the time for this log entry.")
                        }

                        Section {
                            DatePicker(
                                "Select Date",
                                selection: Binding(
                                    get: { customTimestamp ?? Date() },
                                    set: { customTimestamp = $0 }
                                ),
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .listRowInsets(EdgeInsets())
                        }
                    }
                    .navigationTitle("Adjust Time")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showDatePicker = false }
                            .fontWeight(.bold)
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .confirmationDialog("What type of diaper?", isPresented: $showDiaperSheet, titleVisibility: .visible) {
                Button("Pee") { logDiaper(subtype: "Pee") }
                Button("Poop") { logDiaper(subtype: "Poop") }
                Button("Both") { logDiaper(subtype: "Both") }
                Button("Cancel", role: .cancel) { }
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    Text(toastMessage)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.black.opacity(0.8)))
                        .padding(.bottom, 50)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showToast = false }
                            }
                        }
                }
            }
        }
    }

    // --- TIMER SYNC LOGIC ---
    private func checkLiveActivityStatus() {
        isLiveActivityRunning = !Activity<TimerAttributes>.activities.isEmpty
    }

    private func refreshTimerIfNecessary() {
        guard let lastFeed = recentEvents.first(where: { $0.type == "FEED" }) else { return }
        let feedTimestamp = lastFeed.timestamp ?? Date()

        // Check if there's an active Live Activity
        if let currentActivity = Activity<TimerAttributes>.activities.first {
            let currentStartTime = currentActivity.content.state.startTime

            // If cloud data has a feed more than 10 seconds different than our current timer
            if abs(feedTimestamp.timeIntervalSince(currentStartTime)) > 10 {
                startLiveActivity(startTime: feedTimestamp)
            }
        } else {
            // If no timer is running, but a feed happened recently (< 8 hours)
            if abs(feedTimestamp.timeIntervalSinceNow) < 28800 {
                startLiveActivity(startTime: feedTimestamp)
            }
        }
    }

    private func logFeed() {
        let amount = Float(amountText) ?? 0.0
        let timestamp = customTimestamp ?? Date()

        let newEvent = BabyEventEntity(context: viewContext)
        newEvent.id = UUID()
        newEvent.type = "FEED"
        newEvent.subtype = isOz ? "oz" : "ml"
        newEvent.amount = amount
        newEvent.timestamp = timestamp

        do {
            try viewContext.save()
        } catch {
            print("Error saving feed event: \(error)")
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        startLiveActivity(startTime: timestamp)

        amountText = ""
        customTimestamp = nil
        hideKeyboard()
    }

    private func startLiveActivity(startTime: Date) {
        // End any existing activities
        for activity in Activity<TimerAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }

        let attributes = TimerAttributes(babyName: cloudSettings.babyName)
        let state = TimerAttributes.ContentState(startTime: startTime)
        let staleDate = Calendar.current.date(byAdding: .hour, value: 12, to: startTime)
        let activityContent = ActivityContent(state: state, staleDate: staleDate)

        do {
            let _ = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )

            // Update status
            isLiveActivityRunning = true

            toastMessage = "Live Activity Started"
            withAnimation(.spring()) {
                showToast = true
            }
        } catch {
            print("❌ Error starting Live Activity: \(error.localizedDescription)")
            toastMessage = "Error: \(error.localizedDescription)"
            withAnimation { showToast = true }
        }
    }

    private func logDiaper(subtype: String) {
        let newEvent = BabyEventEntity(context: viewContext)
        newEvent.id = UUID()
        newEvent.type = "DIAPER"
        newEvent.subtype = subtype
        newEvent.amount = 0.0
        newEvent.timestamp = customTimestamp ?? Date()

        do {
            try viewContext.save()
        } catch {
            print("Error saving diaper event: \(error)")
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        customTimestamp = nil
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
