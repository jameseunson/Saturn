//
//  Comment.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 9/1/2023.
//

import Foundation

struct Comment: Identifiable, Hashable, Codable {
    let id: Int
    let by: String
    let kids: [Int]?
    let parent: Int
    let text: String
    let time: Date
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.by = try container.decode(String.self, forKey: .by)
        self.kids = try container.decodeIfPresent([Int].self, forKey: .kids)
        self.parent = try container.decode(Int.self, forKey: .parent)
        self.text = try container.decode(String.self, forKey: .text)
        
        let timestamp = try container.decode(TimeInterval.self, forKey: .time)
        self.time = Date(timeIntervalSince1970: timestamp)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case by
        case kids
        case parent
        case text
        case time
    }
}
