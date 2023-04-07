//
//  Color+IndentationColor.swift
//  Saturn
//
//  Created by James Eunson on 14/2/2023.
//

import Foundation
import SwiftUI
import Factory

extension Color {
    static var randomLevelColors: [Int: Color] = [:]
    
    static func indentationColor(for comment: CommentViewModel) -> Color {
        let color = Container.shared.settingsManager().indentationColor()
        if color == .randomLevel {
            if let levelColor = randomLevelColors[comment.indendation] {
                return levelColor
                
            } else {
                let color = Color.random
                randomLevelColors[comment.indendation] = color
                return color
            }
        } else {
            return indentationColor()
        }
    }
    
    static func indentationColor() -> Color {
        let color = Container.shared.settingsManager().indentationColor()
        switch color {
        case .randomLevel:
            return Color.random
        case .none:
            return Color(uiColor: UIColor.systemGray3)
        case .some(.default):
            return Color(uiColor: UIColor.systemGray3)
        case .some(.hnOrange):
            return Color.accentColor
        case .some(.userSelected(color: let color)):
            if let color {
                return color
            } else {
                return Color.gray
            }
        case .some(.randomPost):
            return Color.random
        }
    }
}
