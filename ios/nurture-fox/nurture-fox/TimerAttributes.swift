//
//  TimerAttributes.swift
//  nurture-fox
//
//  Created by Tim OLeary on 1/13/26.
//


import Foundation
import ActivityKit

struct TimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic data: things that change (like the start time)
        var startTime: Date
    }

    // Static data: things that don't change (like the baby's name)
    var babyName: String
}
