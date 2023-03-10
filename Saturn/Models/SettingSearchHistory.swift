//
//  SettingSearchHistory.swift
//  Saturn
//
//  Created by James Eunson on 10/3/2023.
//

import Foundation

struct SettingSearchHistory: Codable, Hashable {
    let history: Array<SettingSearchHistoryItem>
    
    init(history: Array<SettingSearchHistoryItem> = []) {
        self.history = history
    }
    
    func hash(into hasher: inout Hasher) {
        history.forEach { hasher.combine($0) }
    }
}

struct SettingSearchHistoryItem: Codable, Hashable {
    let query: String
    let timestamp: Date
}
