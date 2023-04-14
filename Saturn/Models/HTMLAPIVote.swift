//
//  HTMLAPIVote.swift
//  Saturn
//
//  Created by James Eunson on 29/3/2023.
//

import Foundation

struct HTMLAPIVote: Codable, Hashable {
    let id: Int
    let directions: [HTMLAPIVoteDirection]
    let auth: String
    let storyId: Int
    var state: HTMLAPIVoteDirection?
    
    var dict: [String: Any] {
        var map: [String : Any] = ["id": id,
                                   "directions": directions.map { $0.rawValue },
                                   "auth": auth,
                                   "storyId": storyId
                                  ]
        if let state {
            map["state"] = state.rawValue
        }
        return map
    }
}

extension HTMLAPIVote {
    static func fakeVote() -> HTMLAPIVote {
        HTMLAPIVote(id: 1, directions: [.upvote, .downvote], auth: "asdf", storyId: 1234)
    }
}

enum HTMLAPIVoteDirection: String, Codable, RawRepresentable {
    case upvote = "up"
    case downvote = "down"
    case unvote = "un"
}
