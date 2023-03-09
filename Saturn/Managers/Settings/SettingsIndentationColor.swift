//
//  SettingsIndentationColor.swift
//  Saturn
//
//  Created by James Eunson on 9/3/2023.
//

import Foundation
import SwiftUI

enum SettingIndentationColor: CaseIterable, Codable, Hashable {
    static var allCases: [SettingIndentationColor] {
        [.`default`,
         .hnOrange,
         .userSelected(color: nil),
         .randomLevel,
         .randomPost]
    }
    
    case `default`
    case hnOrange
    case userSelected(color: Color?)
    case randomLevel
    case randomPost
    
    var keys: [String] {
        SettingIndentationColor.allCases.map { description(for: $0) }
    }
    
    func toString() -> String {
        description(for: self)
    }
    
    func description(for key: SettingIndentationColor) -> String {
        switch self {
        case .`default`:
            return "Default (Gray)"
        case .hnOrange:
            return "HN Orange"
        case .userSelected(color: _):
            return "User Selected"
        case .randomLevel:
            return "Random (per level)"
        case .randomPost:
            return "Random (every post)"
        }
    }
}
