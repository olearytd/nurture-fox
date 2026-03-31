//
//  BabyEventEntity+CoreDataProperties.swift
//  nurture-fox
//
//  Created by Migration to Core Data
//

import Foundation
import CoreData

extension BabyEventEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<BabyEventEntity> {
        return NSFetchRequest<BabyEventEntity>(entityName: "BabyEvent")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var type: String?
    @NSManaged public var subtype: String?
    @NSManaged public var amount: Float
    @NSManaged public var timestamp: Date?
    @NSManaged public var note: String?

}

extension BabyEventEntity : Identifiable {

}
