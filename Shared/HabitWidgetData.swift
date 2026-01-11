//
//  HabitWidgetData.swift
//  Habitto
//
//  Created by Chloe Lee on 2026-01-11.
//

import Foundation

// MARK: - Habit Widget Data Model
/// Simplified habit data structure for widget display
/// This is a separate model to avoid importing the full Habit model in the widget extension
/// This file is shared between Habitto and HabittoWidgetExtension targets
struct HabitWidgetData: Codable {
    let id: UUID
    let name: String
    let icon: String
    let completionHistory: [String: Int]
    let completionStatus: [String: Bool]
}
