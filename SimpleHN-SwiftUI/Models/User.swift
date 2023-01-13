//
//  User.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 12/1/2023.
//

import Foundation

struct User: Identifiable, Hashable, Codable {
    let id: String
    let created: Date
    let about: AttributedString?
    let karma: Int
    let submitted: [Int]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        
        let timestamp = try container.decode(TimeInterval.self, forKey: .created)
        self.created = Date(timeIntervalSince1970: timestamp)
        
        let unprocessedText = try container.decodeIfPresent(String.self, forKey: .about)
        if let unprocessedText {
            if let attributedString = try? CommentTextProcessor.processCommentText(unprocessedText) {
                self.about = attributedString
            } else {
                self.about = AttributedString(unprocessedText)
            }
        } else {
            self.about = nil
        }
        
        self.karma = try container.decode(Int.self, forKey: .karma)
        self.submitted = try container.decode([Int].self, forKey: .submitted)
    }
}
