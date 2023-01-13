//
//  StoryRowViewModel.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 13/1/2023.
//

import Foundation

final class StoryRowViewModel: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let subtitle: String
    let score: Int
    let comments: Int
    
    init(story: Story) {
        self.id = story.id
        self.title = story.title
        
        var subtitleComponents = [String]()
        
        if let url = story.url,
        let host = url.host {
            subtitleComponents.append(host)
            subtitleComponents.append(" · ")
        }
        subtitleComponents.append(story.by)
        subtitleComponents.append(" · ")
        subtitleComponents.append(RelativeDateTimeFormatter().localizedString(for: story.time, relativeTo: Date()))
        
        self.subtitle = subtitleComponents.joined()
        
        self.score = story.score
        self.comments = story.descendants ?? 0
    }
    
    static func == (lhs: StoryRowViewModel, rhs: StoryRowViewModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.subtitle == rhs.subtitle &&
               lhs.score == rhs.score &&
               lhs.comments == rhs.comments
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(score)
        hasher.combine(comments)
    }
}
