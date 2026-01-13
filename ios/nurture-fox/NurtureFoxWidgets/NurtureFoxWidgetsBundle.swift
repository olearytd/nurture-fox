//
//  NurtureFoxWidgetsBundle.swift
//  NurtureFoxWidgets
//
//  Created by Tim OLeary on 1/13/26.
//

import WidgetKit
import SwiftUI

@main
struct NurtureFoxWidgetsBundle: WidgetBundle {
    var body: some Widget {
        NurtureFoxWidgets()
        NurtureFoxWidgetsControl()
        NurtureFoxLiveActivity()
    }
}
