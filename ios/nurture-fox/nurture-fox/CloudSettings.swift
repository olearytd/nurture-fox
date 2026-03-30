//
//  CloudSettings.swift
//  nurture-fox
//
//  iCloud-synced settings using NSUbiquitousKeyValueStore
//

import Foundation
import Combine

class CloudSettings: ObservableObject {
    static let shared = CloudSettings()
    
    private let store = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    
    @Published var babyName: String {
        didSet {
            store.set(babyName, forKey: "babyName")
            store.synchronize()
        }
    }
    
    @Published var babyBirthday: Date {
        didSet {
            store.set(babyBirthday.timeIntervalSince1970, forKey: "babyBirthday")
            store.synchronize()
        }
    }
    
    @Published var themePreference: Int {
        didSet {
            store.set(themePreference, forKey: "themePreference")
            store.synchronize()
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load initial values from iCloud (with UserDefaults fallback)
        self.babyName = store.string(forKey: "babyName") ?? UserDefaults.standard.string(forKey: "babyName") ?? "Baby"
        
        let birthdayTimestamp = store.double(forKey: "babyBirthday")
        if birthdayTimestamp > 0 {
            self.babyBirthday = Date(timeIntervalSince1970: birthdayTimestamp)
        } else {
            let fallbackTimestamp = UserDefaults.standard.double(forKey: "babyBirthday")
            self.babyBirthday = Date(timeIntervalSince1970: fallbackTimestamp > 0 ? fallbackTimestamp : Date().timeIntervalSince1970)
        }
        
        self.themePreference = store.longLong(forKey: "themePreference") != 0 ? Int(store.longLong(forKey: "themePreference")) : UserDefaults.standard.integer(forKey: "themePreference")
        
        // Migrate from UserDefaults to iCloud on first launch
        migrateFromUserDefaultsIfNeeded()
        
        // Listen for external changes (from other devices)
        NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
            .sink { [weak self] _ in
                self?.handleExternalChange()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Migration
    
    private func migrateFromUserDefaultsIfNeeded() {
        let migrationKey = "hasCloudSettingsMigrated"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        
        // If iCloud is empty but UserDefaults has values, migrate them
        if store.string(forKey: "babyName") == nil, let name = UserDefaults.standard.string(forKey: "babyName") {
            store.set(name, forKey: "babyName")
        }
        
        if store.double(forKey: "babyBirthday") == 0 {
            let birthday = UserDefaults.standard.double(forKey: "babyBirthday")
            if birthday > 0 {
                store.set(birthday, forKey: "babyBirthday")
            }
        }
        
        if store.longLong(forKey: "themePreference") == 0 {
            let theme = UserDefaults.standard.integer(forKey: "themePreference")
            store.set(theme, forKey: "themePreference")
        }
        
        store.synchronize()
        UserDefaults.standard.set(true, forKey: migrationKey)
        
        print("✅ Migrated settings to iCloud")
    }
    
    // MARK: - External Change Handling
    
    private func handleExternalChange() {
        // Update from iCloud when another device changes values
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let name = self.store.string(forKey: "babyName") {
                self.babyName = name
            }
            
            let birthdayTimestamp = self.store.double(forKey: "babyBirthday")
            if birthdayTimestamp > 0 {
                self.babyBirthday = Date(timeIntervalSince1970: birthdayTimestamp)
            }
            
            let theme = Int(self.store.longLong(forKey: "themePreference"))
            if theme >= 0 {
                self.themePreference = theme
            }
            
            print("📥 Settings updated from iCloud")
        }
    }
}

