//
//  Settings.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 29/4/22.
//

import Foundation
import Combine

class Settings {
    private var settingsMap = [SettingKey: Bool]()
    private let encoder: PropertyListEncoder
    private let decoder: PropertyListDecoder
    private let fm = FileManager.default
    
    public let settings = CurrentValueSubject<[SettingKey: Bool], Never>([:])
    
    public static let `default` = Settings()
    
    init() {
        encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        
        decoder = PropertyListDecoder()
        if let settingsMap = load() {
            self.settingsMap = settingsMap
            settings.send(settingsMap)
        }
    }
    
    func set(value: Bool, for key: SettingKey) {
        settingsMap[key] = value
        settings.send(settingsMap)
        persist()
    }
    
    func value(for key: SettingKey) -> Bool {
        return settingsMap[key] ?? false
    }
    
    // MARK: - Private
    private func load() -> [SettingKey: Bool]? {
        let url = getUrl()
        if fm.fileExists(atPath: url.path),
           let data = fm.contents(atPath: url.path),
           let settings = try? decoder.decode([SettingKey: Bool].self, from: data) {
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

enum SettingKey: String, CaseIterable, Codable {
    case entersReader = "Open URLs in Reader Mode"
}
