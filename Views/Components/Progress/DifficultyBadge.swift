//
//  DifficultyBadge.swift
//  Habitto
//
//  Displays a difficulty rating badge with emoji and label
//

import SwiftUI

struct DifficultyBadge: View {
    let difficulty: Int
    
    private var emoji: String {
        switch difficulty {
        case 1: return "😊"
        case 2: return "🙂"
        case 3: return "😐"
        case 4: return "😓"
        case 5: return "🥵"
        default: return "😐"
        }
    }
    
    private var label: String {
        switch difficulty {
        case 1: return "Very Easy"
        case 2: return "Easy"
        case 3: return "Medium"
        case 4: return "Hard"
        case 5: return "Very Hard"
        default: return "Medium"
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: 11))
            Text(label)
                .font(.appLabelSmall)
                .foregroundColor(.appText04)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.appSurface03)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.appOutline02, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        DifficultyBadge(difficulty: 1)
        DifficultyBadge(difficulty: 2)
        DifficultyBadge(difficulty: 3)
        DifficultyBadge(difficulty: 4)
        DifficultyBadge(difficulty: 5)
    }
    .padding()
}
