//
//  LogDiaperIntent.swift
//  nurture-fox
//
//  Created by Tim OLeary on 1/13/26.
//


import AppIntents
import SwiftData

struct LogDiaperIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log Diaper"

    @Parameter(title: "Type")
    var type: String

    init() {}
    init(type: String) { self.type = type }

    func perform() async throws -> some IntentResult {
        // Access SwiftData with app group and CloudKit
        let groupID = "group.toleary.nurture-fox"
        let schema = Schema([BabyEvent.self, Milestone.self])
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(groupID),
            cloudKitDatabase: .automatic
        )

        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let newEvent = BabyEvent(type: "DIAPER", subtype: type, amount: 0)
        context.insert(newEvent)
        try context.save()

        return .result()
    }
}
