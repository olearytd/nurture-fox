//
//  MilestoneEntity+CoreDataProperties.swift
//  nurture-fox
//
//  Created by Migration to Core Data
//

import Foundation
import CoreData

extension MilestoneEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MilestoneEntity> {
        return NSFetchRequest<MilestoneEntity>(entityName: "Milestone")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var ageAtOccurrence: String?

}

extension MilestoneEntity : Identifiable {

}
