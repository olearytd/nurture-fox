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
        // Access SwiftData in the background
        let container = try ModelContainer(for: BabyEvent.self)
        let context = ModelContext(container)
        
        let newEvent = BabyEvent(type: "DIAPER", subtype: type, amount: 0)
        context.insert(newEvent)
        try context.save()
        
        return .result()
    }
}