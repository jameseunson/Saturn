//
//  Settings.swift
//  Saturn
//
//  Created by James Eunson on 29/4/22.
//

import Foundation
import Combine
import SwiftUI

class Settings {
    private var settingsMap = [SettingKey: SettingValue]()
    private let encoder: PropertyListEncoder
    private let decoder: PropertyListDecoder
    private let fm = FileManager.default
    
    public let settings = CurrentValueSubject<[SettingKey: SettingValue], Never>([:])
    
    public static let `default` = Settings()
    
    public static let types: [SettingKey: SettingType] = [
        .entersReader: .bool,
        .indentationColor: .enum
    ]
    
    private let defaults: [SettingKey: SettingValue] = [
        .entersReader: .bool(false),
        .indentationColor: .indentationColor(.default)
    ]
    
    init() {
        encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        
        decoder = PropertyListDecoder()
        if let settingsMap = load() {
            self.settingsMap = settingsMap
            settings.send(settingsMap)
            
        } else { /// No persisted settings, initialize with defaults and write to disk
            self.settingsMap = defaults
            settings.send(settingsMap)
            persist()
        }
    }
    
    func set(value: SettingValue, for key: SettingKey) {
        settingsMap[key] = value
        settings.send(settingsMap)
        persist()
    }
    
    // MARK: -
    func bool(for key: SettingKey) -> Bool {
        guard case let .bool(value) = settingsMap[key] else {
            return false
        }
        return value
    }
    
    func indentationColor() -> SettingIndentationColor? {
        guard case let .indentationColor(color) = settingsMap[.indentationColor] else {
            return nil
        }
        return color
    }
    
    func color(for key: SettingKey) -> Color? {
        guard case let .color(color) = settingsMap[key] else {
            return nil
        }
        return color
    }
    
    func searchHistory() -> SettingSearchHistory {
        guard case let .searchHistory(value) = settingsMap[.searchHistory] else {
            return SettingSearchHistory()
        }
        return value
    }
    
    // MARK: - Private
    private func load() -> [SettingKey: SettingValue]? {
        let url = getUrl()
        if fm.fileExists(atPath: url.path),
           let data = fm.contents(atPath: url.path),
           let settings = try? decoder.decode([SettingKey: SettingValue].self, from: data) {
            return settings
            
        } else {
            return nil
        }
    }
    
    private func persist() {
        guard let encodedPlistData = try? encoder.encode(settingsMap) else {
            return
        }
        let url = getUrl()
        if fm.fileExists(atPath: url.path) {
            try? fm.removeItem(atPath: url.path)
        }
        fm.createFile(atPath: url.path, contents: encodedPlistData, attributes: nil)
    }
    
    private func getUrl() -> URL {
        let paths = fm.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("Settings.plist")
    }
}

enum SettingType {
    case bool
    case `enum`
}

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
