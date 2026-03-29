//
//  CoreDataManager.swift
//  nurture-fox
//
//  Core Data stack with CloudKit sharing support
//

import Foundation
import CoreData
import CloudKit
import Combine

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()

    let container: NSPersistentCloudKitContainer

    private init() {
        container = NSPersistentCloudKitContainer(name: "NurtureFox")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }

        // Configure for app group
        let groupID = "group.toleary.nurture-fox"
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            let storeURL = groupURL.appendingPathComponent("NurtureFox.sqlite")
            description.url = storeURL
        }

        // Enable CloudKit
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.toleary.nurturefox"
        )

        // Enable history tracking and remote change notifications
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Watch for remote changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: nil
        )
    }

    @objc private func handleRemoteChange(_ notification: Notification) {
        print("📥 Remote change detected")
        objectWillChange.send()
    }

    // MARK: - Sharing

    func canShare(_ object: NSManagedObject) -> Bool {
        return container.canUpdateRecord(forManagedObjectWith: object.objectID)
    }

    func isShared(_ object: NSManagedObject) -> Bool {
        guard let share = try? container.fetchShares(matching: [object.objectID])[object.objectID] else {
            return false
        }
        return share != nil
    }

    func createShare(for objects: [NSManagedObject]) async throws -> CKShare {
        // For now, we'll share all baby events as a single share
        // We need at least one object to create a share
        guard let firstObject = objects.first else {
            throw NSError(domain: "CoreDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No objects to share"])
        }

        let (_, share, _) = try await container.share([firstObject], to: nil)

        // Configure share permissions
        share[CKShare.SystemFieldKey.title] = "Nurture Fox - Baby Tracking"
        share.publicPermission = .none

        return share
    }

    func fetchExistingShare() async throws -> CKShare? {
        // Try to find any existing share in the container
        let context = container.viewContext

        let fetchRequest = BabyEventEntity.fetchRequest()
        fetchRequest.fetchLimit = 1
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        guard let event = try context.fetch(fetchRequest).first else {
            return nil
        }

        let shares = try container.fetchShares(matching: [event.objectID])
        return shares[event.objectID]
    }

    func deleteShare(_ share: CKShare) async throws {
        guard let store = container.persistentStoreCoordinator.persistentStores.first else {
            throw NSError(domain: "CoreDataManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No persistent store found"])
        }
        try await container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: store)
    }
}
