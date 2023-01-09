//
//  Story.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 9/1/2023.
//

import Foundation

struct Story: Codable, Identifiable, Hashable {
    let id: Int
    let score: Int
    let time: Date
    let descendants: Int?
    let by: String
    let title: String
    let kids: [Int]?
    let type: String
    let url: URL?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.score = try container.decode(Int.self, forKey: .score)
        
        let timestamp = try container.decode(TimeInterval.self, forKey: .time)
        self.time = Date(timeIntervalSince1970: timestamp)
        
        self.descendants = try container.decodeIfPresent(Int.self, forKey: .descendants)
        self.by = try container.decode(String.self, forKey: .by)
        self.title = try container.decode(String.self, forKey: .title)
        self.kids = try container.decodeIfPresent([Int].self, forKey: .kids)
        self.type = try container.decode(String.self, forKey: .type)
        self.url = try container.decodeIfPresent(URL.self, forKey: .url)
    }
}
