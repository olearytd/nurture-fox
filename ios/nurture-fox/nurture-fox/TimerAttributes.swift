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
        var startTime: Date
    }

    var babyName: String
}
