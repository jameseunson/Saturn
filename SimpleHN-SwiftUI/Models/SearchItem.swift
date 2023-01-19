//
//  SearchItem.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 19/1/2023.
//

import Foundation

struct SearchItem: Codable {
    let createdAt: Date
    let title: String
    let url: URL?
    let author: String
    let points: Int
    let numComments: Int
    let objectID: Int
    
    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at_i"
        case title
        case url
        case author
        case points
        case numComments = "num_comments"
        case objectID
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let rawDate = try container.decode(TimeInterval.self, forKey: .createdAt)
        self.createdAt = Date(timeIntervalSince1970: rawDate)
        
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try container.decodeIfPresent(URL.self, forKey: .url)
        self.author = try container.decode(String.self, forKey: .author)
        self.points = try container.decode(Int.self, forKey: .points)
        self.numComments = try container.decode(Int.self, forKey: .numComments)
        
        let objectID = try container.decode(String.self, forKey: .objectID)
        if let objectIDInt = Int(objectID) {
            self.objectID = objectIDInt
        } else {
            throw SearchItemError.invalidObjectID
        }
    }
}

enum SearchItemError: Error {
    case invalidObjectID
}
