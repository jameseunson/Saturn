//
//  Settings.swift
//  SimpleHN-SwiftUI
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
    
    init() {
        encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        
        decoder = PropertyListDecoder()
        if let settingsMap = load() {
            self.settingsMap = settingsMap
            settings.send(settingsMap)
        }
    }
    
    func set(value: SettingValue, for key: SettingKey) {
        settingsMap[key] = value
        settings.send(settingsMap)
        persist()
    }
    
    func bool(for key: SettingKey) -> Bool {
        switch settingsMap[key] {
        case let .bool(value):
            return value
        default:
            return false
        }
    }
    
    func indentationColor() -> SettingIndentationColor? {
        switch settingsMap[.indentationColor] {
        case let .indentationColor(color):
            return color
        default:
            return nil
        }
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

enum SettingKey: String, CaseIterable, Codable {
    case entersReader = "Open URLs in Reader Mode"
    case indentationColor = "Comment Indentation Color"
}

enum SettingIndentationColor: CaseIterable, Codable, Hashable {
    static var allCases: [SettingIndentationColor] {
        [.`default`,
         .hnOrange,
         .userSelected(color: nil),
         .random,
         .randomPost]
    }
    
    case `default`
    case hnOrange
    case userSelected(color: Color?)
    case random
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
        case .random:
            return "Random (per level)"
        case .randomPost:
            return "Random (every post)"
        }
    }
}

enum SettingValue: Codable, Hashable {
    static func == (lhs: SettingValue, rhs: SettingValue) -> Bool {
        switch (lhs, rhs) {
            
        case (.bool(let lhsValue), .bool(let rhsValue)):
            return lhsValue == rhsValue
        case (.indentationColor(let lhsValue), .indentationColor(let rhsValue)):
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
        }
    }
    
    case bool(Bool)
    case indentationColor(SettingIndentationColor)
}

enum SettingType {
    case bool
    case `enum`
}
