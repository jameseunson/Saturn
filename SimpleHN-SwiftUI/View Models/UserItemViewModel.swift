//
//  UserItemViewModel.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 31/1/2023.
//

import Foundation
import SwiftUI

enum UserItemViewModel: Identifiable, Equatable {
    var id: Int {
        switch self {
        case let .comment(comment):
            return comment.id
        case let .story(story):
            return story.id
        }
    }
    
    case comment(CommentViewModel)
    case story(StoryRowViewModel)
}
