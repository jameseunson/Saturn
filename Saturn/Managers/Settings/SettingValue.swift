//
//  SettingValue.swift
//  Saturn
//
//  Created by James Eunson on 9/3/2023.
//

import Foundation
import SwiftUI

enum SettingValue: Codable, Hashable {
    static func == (lhs: SettingValue, rhs: SettingValue) -> Bool {
        switch (lhs, rhs) {
            
        case (.bool(let lhsValue), .bool(let rhsValue)):
            return lhsValue == rhsValue
        case (.indentationColor(let lhsValue), .indentationColor(let rhsValue)):
            return lhsValue == rhsValue
        case (.color(let lhsValue), .color(let rhsValue)):
            return lhsValue == rhsValue
        case (.searchHistory(let lhsValue), .searchHistory(let rhsValue)):
            return lhsValue == rhsValue
        case (.date(let lhsValue), .date(let rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case let .bool(value):
            hasher.combine(value)
        case let .indentationColor(value):
            hasher.combine(value)
        case let .color(value):
            hasher.combine(value)
        case let .searchHistory(value):
            hasher.combine(value)
        case let .date(value):
            hasher.combine(value)
        }
    }
    
    case bool(Bool)
    case indentationColor(SettingIndentationColor)
    case color(Color)
    case searchHistory(SettingSearchHistory)
    case date(Date)
}
