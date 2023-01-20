//
//  Comment.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 9/1/2023.
//

import Foundation
import UIKit

struct Comment: Identifiable, Hashable, Codable {
    let id: Int
    let by: String
    let kids: [Int]?
    let parent: Int
    let text: AttributedString
    let time: Date
    
    var url: URL? {
        return URL(string: "https://news.ycombinator.com/item?id=\(id)")
    }
    
    init(id: Int, by: String, kids: [Int]?, parent: Int, text: AttributedString, time: Date) {
        self.id = id
        self.by = by
        self.kids = kids
        self.parent = parent
        self.text = text
        self.time = time
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.by = try container.decode(String.self, forKey: .by)
        self.kids = try container.decodeIfPresent([Int].self, forKey: .kids)
        self.parent = try container.decode(Int.self, forKey: .parent)
        
        let unprocessedText = try container.decode(String.self, forKey: .text)
        if let attributedString = try? CommentTextProcessor.processCommentText(unprocessedText) {
            self.text = attributedString
        } else {
            self.text = AttributedString(unprocessedText)
        }
        
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
