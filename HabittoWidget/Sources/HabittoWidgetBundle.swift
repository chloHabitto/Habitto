//
//  HabittoWidgetBundle.swift
//  HabittoWidget
//
//  Widget bundle entry point - declares all widgets in the extension
//

import WidgetKit
import SwiftUI

@main
struct HabittoWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Main habit tracking widget
        HabittoWidget()
        
        // Control widget for Control Center (optional - comment out if not needed yet)
        // HabittoWidgetControl()
        
        // Live Activity widget for Dynamic Island (optional - comment out if not needed yet)
        // HabittoWidgetLiveActivity()
    }
}
