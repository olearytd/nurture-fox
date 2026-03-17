//
//  BabyEvent.swift
//  nurture-fox
//
//  Created by Tim OLeary on 1/9/26.
//


import Foundation
import SwiftData

@Model
final class BabyEvent {
    var id: UUID = UUID()
    var type: String = "FEED"
    var subtype: String = "oz"
    var amount: Float = 0.0
    var timestamp: Date = Date()
    var note: String?

    init(id: UUID = UUID(), type: String = "FEED", subtype: String = "oz", amount: Float = 0.0, timestamp: Date = Date(), note: String? = nil) {
        self.id = id
        self.type = type
        self.subtype = subtype
        self.amount = amount
        self.timestamp = timestamp
        self.note = note
    }
}

@Model
final class Milestone {
    var id: UUID = UUID()
    var name: String = ""
    var timestamp: Date = Date()
    var ageAtOccurrence: String = ""

    init(id: UUID = UUID(), name: String = "", timestamp: Date = Date(), ageAtOccurrence: String = "") {
        self.id = id
        self.name = name
        self.timestamp = timestamp
        self.ageAtOccurrence = ageAtOccurrence
    }
}
