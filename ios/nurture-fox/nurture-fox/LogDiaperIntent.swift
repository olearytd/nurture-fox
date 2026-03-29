//
//  LogDiaperIntent.swift
//  nurture-fox
//
//  Created by Tim OLeary on 1/13/26.
//


import AppIntents
import CoreData

struct LogDiaperIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log Diaper"

    @Parameter(title: "Type")
    var type: String

    init() {}
    init(type: String) { self.type = type }

    func perform() async throws -> some IntentResult {
        // Access Core Data through shared manager
        let coreDataManager = CoreDataManager.shared
        let context = coreDataManager.container.viewContext

        let newEvent = BabyEventEntity(context: context)
        newEvent.id = UUID()
        newEvent.type = "DIAPER"
        newEvent.subtype = type
        newEvent.amount = 0
        newEvent.timestamp = Date()

        try context.save()

        return .result()
    }
}
