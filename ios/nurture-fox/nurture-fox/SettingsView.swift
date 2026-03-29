import SwiftUI
import SwiftData
import CloudKit
import UniformTypeIdentifiers
import WidgetKit
import CoreData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var coreDataManager: CoreDataManager

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BabyEventEntity.timestamp, ascending: true)],
        animation: .default)
    private var allEvents: FetchedResults<BabyEventEntity>

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
    @State private var isLoadingShare = false
    @State private var shareError: String?

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
                Section(header: Text("Family Sharing"), footer: Text(activeShare == nil ? "Invite your partner to collaborate on baby tracking. They'll need their own iCloud account." : "Your data is currently being shared. Your partner can access all events.")) {
                    if isLoadingShare {
                        HStack {
                            Label("Loading...", systemImage: "hourglass")
                            Spacer()
                            ProgressView()
                        }
                    } else if let error = shareError {
                        VStack(alignment: .leading) {
                            Label("Sharing Error", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if activeShare == nil {
                        Button {
                            Task {
                                await initiateSharing()
                            }
                        } label: {
                            Label("Invite Partner", systemImage: "person.badge.plus")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Sharing Active", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)

                            Button {
                                Task {
                                    await reshareOrManage()
                                }
                            } label: {
                                Label("Manage Sharing", systemImage: "person.2")
                            }

                            Button(role: .destructive) {
                                Task {
                                    await stopSharing()
                                }
                            } label: {
                                Label("Stop Sharing", systemImage: "xmark.circle")
                            }
                        }
                    }
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
                        Task {
                            await fetchExistingShare()
                        }
                    }
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

    private func fetchExistingShare() async {
        await MainActor.run {
            isLoadingShare = true
            shareError = nil
        }

        do {
            let share = try await coreDataManager.fetchExistingShare()
            await MainActor.run {
                self.activeShare = share
                self.isLoadingShare = false
            }
        } catch {
            await MainActor.run {
                self.shareError = "Failed to check sharing status: \(error.localizedDescription)"
                self.isLoadingShare = false
            }
            print("❌ Sharing: Fetch failed - \(error.localizedDescription)")
        }
    }

    private func initiateSharing() async {
        print("🔵 Sharing: Creating share...")

        await MainActor.run {
            isLoadingShare = true
            shareError = nil
        }

        do {
            // Get all events to share
            let eventsToShare = Array(allEvents)
            guard !eventsToShare.isEmpty else {
                await MainActor.run {
                    shareError = "No data to share yet. Add some events first!"
                    isLoadingShare = false
                }
                return
            }

            // Create the share
            let share = try await coreDataManager.createShare(for: eventsToShare)

            await MainActor.run {
                self.activeShare = share
                self.activeContainer = CKContainer(identifier: "iCloud.com.toleary.nurturefox")
                self.isLoadingShare = false
                self.isSharingSheetPresented = true
            }

            print("✅ Sharing: Share created successfully!")
        } catch {
            await MainActor.run {
                self.shareError = "Failed to create share: \(error.localizedDescription)"
                self.isLoadingShare = false
            }
            print("❌ Sharing: Creation failed - \(error.localizedDescription)")
        }
    }

    private func reshareOrManage() async {
        guard let share = activeShare else { return }

        await MainActor.run {
            self.activeContainer = CKContainer(identifier: "iCloud.com.toleary.nurturefox")
            self.isSharingSheetPresented = true
        }
    }

    private func stopSharing() async {
        guard let share = activeShare else { return }

        await MainActor.run {
            isLoadingShare = true
        }

        do {
            try await coreDataManager.deleteShare(share)
            await MainActor.run {
                self.activeShare = nil
                self.isLoadingShare = false
            }
            print("✅ Sharing: Stopped successfully")
        } catch {
            await MainActor.run {
                self.shareError = "Failed to stop sharing: \(error.localizedDescription)"
                self.isLoadingShare = false
            }
            print("❌ Sharing: Stop failed - \(error.localizedDescription)")
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
            let ts = formatter.string(from: event.timestamp ?? Date())
            let type = event.type ?? "FEED"
            let subtype = event.subtype ?? "oz"
            let row = "\(ts),\(type),\(subtype),\(event.amount)\n"
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

            // Delete all existing events
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = BabyEventEntity.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try viewContext.execute(deleteRequest)

            let formatter = ISO8601DateFormatter()
            for (index, row) in rows.enumerated() {
                if index == 0 { continue }
                let columns = row.components(separatedBy: ",")
                if columns.count == 4 {
                    let date = formatter.date(from: columns[0]) ?? Date()
                    let type = columns[1]; let subtype = columns[2]; let amount = Float(columns[3]) ?? 0.0

                    let newEvent = BabyEventEntity(context: viewContext)
                    newEvent.id = UUID()
                    newEvent.type = type
                    newEvent.subtype = subtype
                    newEvent.amount = amount
                    newEvent.timestamp = date
                }
            }
            try viewContext.save()
            WidgetCenter.shared.reloadAllTimelines()
            dismiss()
        } catch { print("Import failed: \(error)") }
    }

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
