import SwiftUI
import SwiftData
import CloudKit
import UniformTypeIdentifiers
import WidgetKit
import CoreData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \BabyEvent.timestamp) private var allEvents: [BabyEvent]
    
    @AppStorage("babyName") private var babyName: String = "Baby"
    @AppStorage("babyBirthday") private var babyBirthday: Double = Date().timeIntervalSince1970
    @AppStorage("themePreference") private var themePreference: Int = 0
    @AppStorage("lastBackupDate") private var lastBackupDate: Double = 0
    
    @State private var accountStatus: CKAccountStatus = .couldNotDetermine
    
    // Backup/Restore States
    @State private var showImportPicker = false
    @State private var showRestoreAlert = false
    @State private var selectedFileURL: URL?
    
    // --- SHARING STATE ---
    @State private var isSharingSheetPresented = false
    @State private var activeShare: CKShare?
    @State private var activeContainer: CKContainer?
    @State private var lastSyncTime: Date? = nil

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

                // --- SHARING SECTION ---
                Section(header: Text("Family Sharing"), footer: Text("Invite a partner to view and log data together using their own iCloud account.")) {
                    Button {
                        initiateSharing()
                    } label: {
                        HStack {
                            Label(activeShare == nil ? "Invite Partner" : "Manage Family Sharing",
                                  systemImage: activeShare == nil ? "person.badge.plus" : "person.2.fill")
                            Spacer()
                            if let share = activeShare {
                                Text("\(share.participants.count) Active")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(accountStatus != .available)
                }

                Section("Cloud Sync") {
                    HStack {
                        Image(systemName: cloudIcon)
                            .foregroundStyle(cloudColor)
                        VStack(alignment: .leading) {
                            Text(cloudStatusText)
                                .font(.subheadline)
                            
                            if let lastSync = lastSyncTime {
                                Text("Last synced: \(lastSync.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(cloudDetailText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onAppear {
                        checkCloudStatus()
                        fetchExistingShare()
                    }
                    // Listen for silent background syncs from the partner
                    .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
                        self.lastSyncTime = Date()
                    }
                }

                Section(header: Text("Data Management"), footer: Text("Backups are saved as .csv files. Restoring will replace all current data.")) {
                    Button(action: exportCSV) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Backup to Files (CSV)", systemImage: "square.and.arrow.up")
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
            .sheet(isPresented: $isSharingSheetPresented) {
                if let share = activeShare {
                    CloudSharingView(share: share, container: CKContainer(identifier: "iCloud.com.toleary.nurturefox"))
                }
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

    // --- SHARING LOGIC ---
        
    private func fetchExistingShare() {
        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.toleary.nurturefox")
                let database = container.privateCloudDatabase
                let zoneID = CKRecordZone.ID(zoneName: "NurtureFoxZone", ownerName: CKCurrentUserDefaultName)
                
                let query = CKQuery(recordType: "cloudkit.share", predicate: NSPredicate(value: true))
                let (results, _) = try await database.records(matching: query, inZoneWith: zoneID)
                
                if let firstResult = results.first {
                    let recordResult = firstResult.1
                    if case .success(let record) = recordResult, let share = record as? CKShare {
                        await MainActor.run {
                            self.activeShare = share
                        }
                    }
                }
            } catch {
                print("No existing share found in custom zone.")
            }
        }
    }

    private func initiateSharing() {
        Task {
            let container = CKContainer(identifier: "iCloud.com.toleary.nurturefox")
            let privateDB = container.privateCloudDatabase
            self.activeContainer = container
            
            // 1. Create a Custom Zone ID (Sharing cannot happen in Default Zone)
            let zoneID = CKRecordZone.ID(zoneName: "NurtureFoxZone", ownerName: CKCurrentUserDefaultName)
            let customZone = CKRecordZone(zoneID: zoneID)
            
            do {
                // 2. Save the Custom Zone to initialize it on server
                try await privateDB.save(customZone)
                
                // 3. Create/Prepare the Share in that Custom Zone
                let share = CKShare(recordZoneID: zoneID)
                share[CKShare.SystemFieldKey.title] = "Nurture Fox Family Data" as CKRecordValue
                
                // 4. Force save the share to server before presenting UI
                try await privateDB.save(share)
                
                await MainActor.run {
                    self.activeShare = share
                    self.isSharingSheetPresented = true
                }
            } catch {
                let ckError = error as? CKError
                if ckError?.code == .serverRecordChanged || ckError?.code == .zoneBusy || ckError?.code == .alreadyShared {
                    fetchExistingShare()
                    await MainActor.run { self.isSharingSheetPresented = true }
                } else {
                    print("Critical Sharing Error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func checkCloudStatus() {
        CKContainer(identifier: "iCloud.com.toleary.nurturefox").accountStatus { status, _ in
            DispatchQueue.main.async {
                self.accountStatus = status
            }
        }
    }

    // --- DATA MANAGEMENT LOGIC ---
    
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
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene, let window = scene.windows.first {
                var topVC = window.rootViewController
                while let presentedVC = topVC?.presentedViewController { topVC = presentedVC }
                activityVC.popoverPresentationController?.sourceView = topVC?.view
                topVC?.present(activityVC, animated: true)
                lastBackupDate = Date().timeIntervalSince1970
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } catch { print("Export failed: \(error)") }
    }

    private func importCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            try modelContext.delete(model: BabyEvent.self)
            let formatter = ISO8601DateFormatter()
            for (index, row) in rows.enumerated() {
                if index == 0 { continue }
                let columns = row.components(separatedBy: ",")
                if columns.count == 4 {
                    let date = formatter.date(from: columns[0]) ?? Date()
                    let type = columns[1]; let subtype = columns[2]; let amount = Float(columns[3]) ?? 0.0
                    let newEvent = BabyEvent(type: type, subtype: subtype, amount: amount, timestamp: date)
                    modelContext.insert(newEvent)
                }
            }
            try modelContext.save()
            WidgetCenter.shared.reloadAllTimelines()
            dismiss()
        } catch { print("Import failed: \(error)") }
    }

    // --- CLOUD STATUS UI HELPERS ---

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
        case .available: return "checkmark.icloud.fill"
        case .noAccount: return "icloud.slash"
        default: return "icloud"
        }
    }

    private var cloudColor: Color { accountStatus == .available ? .green : .orange }
}

// --- CLOUDKIT UI WRAPPER ---
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowPublic, .allowPrivate, .allowReadWrite]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
}
