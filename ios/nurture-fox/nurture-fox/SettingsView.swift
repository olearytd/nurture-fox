import SwiftUI
import SwiftData
import CloudKit
import UniformTypeIdentifiers
import WidgetKit // Added for timeline refreshes

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Fetch all events for the backup process
    @Query(sort: \BabyEvent.timestamp) private var allEvents: [BabyEvent]
    
    @AppStorage("babyName") private var babyName: String = "Baby"
    @AppStorage("babyBirthday") private var babyBirthday: Double = Date().timeIntervalSince1970
    @AppStorage("themePreference") private var themePreference: Int = 0
    
    // New: Track the last backup timestamp
    @AppStorage("lastBackupDate") private var lastBackupDate: Double = 0
    
    @State private var accountStatus: CKAccountStatus = .couldNotDetermine
    
    // Backup/Restore States
    @State private var showImportPicker = false
    @State private var showRestoreAlert = false
    @State private var selectedFileURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section("Baby Profile") {
                    TextField("Baby Name", text: $babyName)
                    DatePicker("Birthday", selection: Binding(
                        get: { Date(timeIntervalSince1970: babyBirthday) },
                        set: { babyBirthday = $0.timeIntervalSince1970 }
                    ), in: ...Date(), displayedComponents: .date)
                }

                Section("Cloud Sync") {
                    HStack {
                        Image(systemName: cloudIcon)
                            .foregroundStyle(cloudColor)
                        VStack(alignment: .leading) {
                            Text(cloudStatusText)
                                .font(.subheadline)
                            Text(cloudDetailText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onAppear { checkCloudStatus() }
                }

                Section(header: Text("Data Management"), footer: Text("Backups are saved as .csv files. Restoring will replace all current data.")) {
                    Button(action: exportCSV) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Backup to Files (CSV)", systemImage: "square.and.arrow.up")
                            
                            // Added: Display the last backup date if it exists
                            if lastBackupDate > 0 {
                                Text("Last backup: \(Date(timeIntervalSince1970: lastBackupDate).formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Button(role: .destructive) {
                        showImportPicker = true
                    } label: {
                        Label("Restore from Backup", systemImage: "square.and.arrow.down")
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $themePreference) {
                        Text("System").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                Button("Done") { dismiss() }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        self.selectedFileURL = url
                        self.showRestoreAlert = true
                    }
                case .failure(let error):
                    print("Import failed: \(error.localizedDescription)")
                }
            }
            .alert("Replace all data?", isPresented: $showRestoreAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Restore", role: .destructive) {
                    if let url = selectedFileURL {
                        importCSV(from: url)
                    }
                }
            } message: {
                Text("This will delete all current logs and replace them with the data from your backup file. This cannot be undone.")
            }
        }
    }

    // --- BACKUP LOGIC ---
    
    private func exportCSV() {
        var csvString = "timestamp,type,subtype,amount\n"
        let formatter = ISO8601DateFormatter()
        
        for event in allEvents {
            let ts = formatter.string(from: event.timestamp)
            let row = "\(ts),\(event.type),\(event.subtype),\(event.amount)\n"
            csvString.append(row)
        }
        
        let fileManager = FileManager.default
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent("\(babyName)_Backup.csv")
        
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            
            #if targetEnvironment(simulator)
            print("📁 Backup created at: \(tempURL.path)")
            #endif
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first {
                
                var topVC = window.rootViewController
                while let presentedVC = topVC?.presentedViewController {
                    topVC = presentedVC
                }
                
                // iPad Support
                activityVC.popoverPresentationController?.sourceView = topVC?.view
                activityVC.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
                activityVC.popoverPresentationController?.permittedArrowDirections = []
                
                topVC?.present(activityVC, animated: true)
                
                // Update the last backup timestamp on successful presentation
                lastBackupDate = Date().timeIntervalSince1970
            }
            
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
        } catch {
            print("Export failed: \(error)")
        }
    }

    // --- RESTORE LOGIC ---
    
    private func importCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            // Wipe current data
            try modelContext.delete(model: BabyEvent.self)
            
            let formatter = ISO8601DateFormatter()
            
            for (index, row) in rows.enumerated() {
                if index == 0 { continue }
                let columns = row.components(separatedBy: ",")
                if columns.count == 4 {
                    let date = formatter.date(from: columns[0]) ?? Date()
                    let type = columns[1]
                    let subtype = columns[2]
                    let amount = Float(columns[3]) ?? 0.0
                    
                    let newEvent = BabyEvent(type: type, subtype: subtype, amount: amount, timestamp: date)
                    modelContext.insert(newEvent)
                }
            }
            
            try modelContext.save()
            
            // Success: Tell Widgets and Live Activities to refresh immediately
            WidgetCenter.shared.reloadAllTimelines()
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            dismiss()
            
        } catch {
            print("Import failed: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // --- CLOUD LOGIC ---
    
    private var cloudStatusText: String {
        switch accountStatus {
        case .available: return "iCloud Synced"
        case .noAccount: return "Not Signed In"
        case .restricted: return "Sync Restricted"
        default: return "Syncing..."
        }
    }

    private var cloudDetailText: String {
        switch accountStatus {
        case .available: return "Data is backing up to your iCloud account."
        case .noAccount: return "Sign in to iCloud in Settings to sync data across devices."
        default: return "Check your internet connection or iCloud settings."
        }
    }

    private var cloudIcon: String {
        switch accountStatus {
        case .available: return "icloud.checkmark.fill"
        case .noAccount: return "icloud.slash"
        default: return "icloud"
        }
    }

    private var cloudColor: Color {
        accountStatus == .available ? .green : .orange
    }

    private func checkCloudStatus() {
        CKContainer.default().accountStatus { status, error in
            DispatchQueue.main.async {
                self.accountStatus = status
            }
        }
    }
}
