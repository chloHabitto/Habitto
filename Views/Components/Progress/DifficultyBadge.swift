//
//  DifficultyBadge.swift
//  Habitto
//
//  Displays a difficulty rating badge with image and label
//  Used in Today's Journey to show the difficulty recorded when a habit was completed
//

import SwiftUI

struct DifficultyBadge: View {
    let difficulty: Int
    
    private var imageName: String {
        switch difficulty {
        case 1: return "Image-VeryEasy"
        case 2: return "Image-Easy"
        case 3: return "Image-Medium"
        case 4: return "Image-Hard"
        case 5: return "Image-VeryHard"
        default: return "Image-Medium"
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
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
            
            Text(label)
                .font(.appLabelSmall)
                .fontWeight(.semibold)
                .foregroundColor(.appText03)
        }
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.appSurface04)
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
