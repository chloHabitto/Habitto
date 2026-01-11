//
//  HabittoWidgetBundle.swift
//  HabittoWidget
//
//  Created by Chloe Lee on 2026-01-11.
//

import WidgetKit
import SwiftUI

@main
struct HabittoWidgetBundle: WidgetBundle {
    var body: some Widget {
        HabittoWidget()
        if #available(iOS 17.0, *) {
            MonthlyProgressWidget()
        }
    }
}
