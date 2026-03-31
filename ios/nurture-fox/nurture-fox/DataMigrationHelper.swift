//
//  DataMigrationHelper.swift
//  nurture-fox
//
//  Migrates data from SwiftData to Core Data
//

import Foundation
import SwiftData
import CoreData

class DataMigrationHelper {
    
    static func migrateIfNeeded() {
        let userDefaults = UserDefaults.standard
        let migrationKey = "hasCompletedSwiftDataToCoreDataMigration"
        
        // Check if migration has already been completed
        if userDefaults.bool(forKey: migrationKey) {
            print("✅ Migration already completed, skipping...")
            return
        }
        
        print("🔄 Starting migration from SwiftData to Core Data...")
        
        do {
            try performMigration()
            userDefaults.set(true, forKey: migrationKey)
            print("✅ Migration completed successfully!")
        } catch {
            print("❌ Migration failed: \(error)")
            // Don't mark as complete so it will retry next time
        }
    }
    
    private static func performMigration() throws {
        // Create SwiftData container to read old data
        let groupID = "group.toleary.nurture-fox"
        let schema = Schema([BabyEvent.self, Milestone.self])
        
        let swiftDataConfig = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(groupID),
            cloudKitDatabase: .none  // Don't sync during migration
        )
        
        let swiftDataContainer = try ModelContainer(for: schema, configurations: [swiftDataConfig])
        let swiftDataContext = ModelContext(swiftDataContainer)
        
        // Fetch all events and milestones from SwiftData
        let eventDescriptor = FetchDescriptor<BabyEvent>(sortBy: [SortDescriptor(\.timestamp)])
        let milestoneDescriptor = FetchDescriptor<Milestone>(sortBy: [SortDescriptor(\.timestamp)])
        
        let events = try swiftDataContext.fetch(eventDescriptor)
        let milestones = try swiftDataContext.fetch(milestoneDescriptor)
        
        print("📊 Found \(events.count) events and \(milestones.count) milestones to migrate")
        
        // Get Core Data context
        let coreDataManager = CoreDataManager.shared
        let coreDataContext = coreDataManager.container.viewContext
        
        // Migrate events
        for event in events {
            let coreDataEvent = BabyEventEntity(context: coreDataContext)
            coreDataEvent.id = event.id
            coreDataEvent.type = event.type
            coreDataEvent.subtype = event.subtype
            coreDataEvent.amount = event.amount
            coreDataEvent.timestamp = event.timestamp
            coreDataEvent.note = event.note
        }
        
        // Migrate milestones
        for milestone in milestones {
            let coreDataMilestone = MilestoneEntity(context: coreDataContext)
            coreDataMilestone.id = milestone.id
            coreDataMilestone.name = milestone.name
            coreDataMilestone.timestamp = milestone.timestamp
            coreDataMilestone.ageAtOccurrence = milestone.ageAtOccurrence
        }
        
        // Save to Core Data
        try coreDataContext.save()
        
        print("✅ Successfully migrated all data to Core Data")
    }
}

