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
    let author: String
    let timeAgo: String
    let score: Int
    let comments: Int
    let url: URL?
    let imageURL: URL?
    let text: AttributedString?
    
    init(story: Story) {
        self.id = story.id
        self.title = story.title
        self.text = story.text
        
        self.author = story.by
        self.timeAgo = RelativeDateTimeFormatter().localizedString(for: story.time, relativeTo: Date())
        
        self.score = story.score
        self.comments = story.descendants ?? 0
        self.url = story.url
        self.imageURL = story.urlForFavicon()
    }
    
    init(searchItem: SearchItem) {
        self.id = searchItem.objectID
        self.title = searchItem.title
        
        self.author = searchItem.author
        self.timeAgo = RelativeDateTimeFormatter().localizedString(for: searchItem.createdAt, relativeTo: Date())
        
        self.score = searchItem.points
        self.comments = searchItem.numComments
        self.url = searchItem.url
        
        self.imageURL = nil
        self.text = nil
    }
    
    static func == (lhs: StoryRowViewModel, rhs: StoryRowViewModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.author == rhs.author &&
               lhs.timeAgo == rhs.timeAgo &&
               lhs.score == rhs.score &&
               lhs.comments == rhs.comments
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(author)
        hasher.combine(timeAgo)
        hasher.combine(score)
        hasher.combine(comments)
    }
}
