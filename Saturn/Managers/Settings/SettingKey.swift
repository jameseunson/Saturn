//
//  SettingKey.swift
//  Saturn
//
//  Created by James Eunson on 9/3/2023.
//

import Foundation
import SwiftUI

enum SettingKey: String, CaseIterable, Codable {
    case entersReader = "Open URLs in Reader Mode"
    case indentationColor = "Comment Indentation Color"
    case lastUserSelectedColor = "Last User Selected Color"
    case searchHistory = "Search History"
    case lastRefreshTimestamp = "Last Refresh Timestamp"
    
    func isUserConfigurable() -> Bool {
        switch self {
        case .entersReader, .indentationColor:
            return true
        case .lastUserSelectedColor, .searchHistory, .lastRefreshTimestamp:
            return false
        }
    }
}
