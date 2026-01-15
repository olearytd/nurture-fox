//
//  SettingsView.swift
//  nurture-fox
//
//  Created by Tim OLeary on 1/9/26.
//


import SwiftUI
import SwiftData
import CloudKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("babyName") private var babyName: String = "Baby"
    @AppStorage("babyBirthday") private var babyBirthday: Double = Date().timeIntervalSince1970
    @AppStorage("themePreference") private var themePreference: Int = 0
    
    // Check if iCloud is actually active
    @State private var accountStatus: CKAccountStatus = .couldNotDetermine

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
                    .onAppear {
                        checkCloudStatus()
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
