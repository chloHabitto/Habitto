//
//  HabittoWidgetBundle.swift
//  HabittoWidget
//
//  Created by Chloe Lee on 2026-01-10.
//

import WidgetKit
import SwiftUI

@main
struct HabittoWidgetBundle: WidgetBundle {
    var body: some Widget {
        HabittoWidget()
        HabittoWidgetControl()
        HabittoWidgetLiveActivity()
    }
}
