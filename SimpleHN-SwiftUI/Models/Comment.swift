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
    let kids: [Int]
    let parent: Int
    let text: String
    let time: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case by
        case kids
        case parent
        case text
        case time
    }
}
