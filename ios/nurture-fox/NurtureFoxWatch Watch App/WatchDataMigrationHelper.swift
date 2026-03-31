//
//  WatchDataMigrationHelper.swift
//  NurtureFoxWatch Watch App
//
//  Migrates Watch app data from SwiftData to Core Data
//

import Foundation
import SwiftData
import CoreData
import WatchKit

class WatchDataMigrationHelper {
    
    static func migrateIfNeeded() {
        let userDefaults = UserDefaults.standard
        let migrationKey = "hasCompletedWatchSwiftDataToCoreDataMigration"
        
        // Check if migration has already been completed
        if userDefaults.bool(forKey: migrationKey) {
            print("✅ Watch migration already completed, skipping...")
            return
        }
        
        print("🔄 Starting Watch migration from SwiftData to Core Data...")
        
        do {
            try performMigration()
            userDefaults.set(true, forKey: migrationKey)
            print("✅ Watch migration completed successfully!")
        } catch {
            print("❌ Watch migration failed: \(error)")
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
        
        print("📊 Watch found \(events.count) events and \(milestones.count) milestones to migrate")
        
        // Skip if no data to migrate
        if events.isEmpty && milestones.isEmpty {
            print("ℹ️ No Watch SwiftData to migrate")
            return
        }
        
        // Get Core Data context
        let coreDataManager = CoreDataManager.shared
        let coreDataContext = coreDataManager.container.viewContext
        
        // Check if events already exist in Core Data (to avoid duplicates)
        let existingIDs = try fetchExistingEventIDs(context: coreDataContext)
        
        var migratedCount = 0
        
        // Migrate events (only if they don't already exist)
        for event in events {
            if !existingIDs.contains(event.id) {
                let coreDataEvent = BabyEventEntity(context: coreDataContext)
                coreDataEvent.id = event.id
                coreDataEvent.type = event.type
                coreDataEvent.subtype = event.subtype
                coreDataEvent.amount = event.amount
                coreDataEvent.timestamp = event.timestamp
                coreDataEvent.note = event.note
                migratedCount += 1
            }
        }
        
        // Migrate milestones (only if they don't already exist)
        let existingMilestoneIDs = try fetchExistingMilestoneIDs(context: coreDataContext)
        
        for milestone in milestones {
            if !existingMilestoneIDs.contains(milestone.id) {
                let coreDataMilestone = MilestoneEntity(context: coreDataContext)
                coreDataMilestone.id = milestone.id
                coreDataMilestone.name = milestone.name
                coreDataMilestone.timestamp = milestone.timestamp
                coreDataMilestone.ageAtOccurrence = milestone.ageAtOccurrence
                migratedCount += 1
            }
        }
        
        // Save to Core Data
        if migratedCount > 0 {
            try coreDataContext.save()
            print("✅ Successfully migrated \(migratedCount) items from Watch SwiftData to Core Data")
        } else {
            print("ℹ️ All Watch data already exists in Core Data, no migration needed")
        }
    }
    
    private static func fetchExistingEventIDs(context: NSManagedObjectContext) throws -> Set<UUID> {
        let fetchRequest = BabyEventEntity.fetchRequest()
        fetchRequest.propertiesToFetch = ["id"]
        let events = try context.fetch(fetchRequest)
        return Set(events.compactMap { $0.id })
    }
    
    private static func fetchExistingMilestoneIDs(context: NSManagedObjectContext) throws -> Set<UUID> {
        let fetchRequest = MilestoneEntity.fetchRequest()
        fetchRequest.propertiesToFetch = ["id"]
        let milestones = try context.fetch(fetchRequest)
        return Set(milestones.compactMap { $0.id })
    }
}

