//
//  UserItem.swift
//  Saturn
//
//  Created by James Eunson on 19/1/2023.
//

import Foundation

enum UserItem {
    case comment(Comment)
    case story(Story)
    
    var time: Date {
        switch self {
        case let .story(story):
            return story.time
            
        case let .comment(comment):
            return comment.time
        }
    }
}
