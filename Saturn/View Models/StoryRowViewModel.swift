//
//  StoryRowViewModel.swift
//  Saturn
//
//  Created by James Eunson on 13/1/2023.
//

import Foundation
import SwiftUI

final class StoryRowViewModel: Codable, Identifiable, Hashable {
    let id: Int
    let story: Story
    let title: String
    let author: String
    let timeAgo: String
    let score: String
    let comments: String
    let url: URL?
    let imageURL: URL?
    let text: AttributedString?
    
    var image: Image?
    var vote: HTMLAPIVote?
    
    init(story: Story, image: Image? = nil) {
        self.id = story.id
        self.title = story.title
        self.text = story.text
        
        self.author = story.by
        self.timeAgo = RelativeDateTimeFormatter().localizedString(for: story.time, relativeTo: Date())
        
        if story.score >= 1000 {
            self.score = String(format: "%.1f", Double(story.score) / 1000) + "k"
        } else {
            self.score = String(story.score)
        }
        let kids = story.descendants ?? 0
        if kids >= 1000 {
            self.comments = String(format: "%.1f", Double(kids) / 1000) + "k"
        } else {
            self.comments = String(kids)
        }
        self.url = story.url
        self.imageURL = story.urlForFavicon()
        self.image = image
        self.story = story
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
    
    enum CodingKeys: CodingKey {
        case id
        case title
        case author
        case timeAgo
        case score
        case comments
        case url
        case imageURL
        case text
        case story
    }
}
