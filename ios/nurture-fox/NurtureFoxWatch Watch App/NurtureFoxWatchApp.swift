//
//  NurtureFoxWatchApp.swift
//  NurtureFoxWatch Watch App
//
//  Created by Tim OLeary on 1/14/26.
//

import SwiftUI
import CoreData

@main
struct NurtureFoxWatch_Watch_AppApp: App {
    let coreDataManager = CoreDataManager.shared

    init() {
        // Migrate any existing SwiftData to Core Data
        WatchDataMigrationHelper.migrateIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(\.managedObjectContext, coreDataManager.container.viewContext)
        }
    }
}
