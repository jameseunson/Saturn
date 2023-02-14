//
//  Color+IndentationColor.swift
//  Saturn
//
//  Created by James Eunson on 14/2/2023.
//

import Foundation
import SwiftUI

extension Color {
    static func indentationColor() -> Color {
        let color = Settings.default.indentationColor()
        switch color {
        case .random:
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
