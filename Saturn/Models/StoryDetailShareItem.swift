//
//  StoryDetailShareItem.swift
//  Saturn
//
//  Created by James Eunson on 19/1/2023.
//

import Foundation

enum StoryDetailShareItem {
    case story(StoryRowViewModel)
    case comment(CommentViewModel)
    
    var url: URL? {
        var url: URL?
        switch self {
            case let .comment(comment):
                url = comment.comment.url
            
            case let .story(story):
                url = story.story.url
        }
        return url
    }
}
