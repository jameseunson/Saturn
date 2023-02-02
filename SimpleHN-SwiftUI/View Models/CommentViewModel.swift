//
//  CommentViewModel.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 10/1/2023.
//

import Foundation

final class CommentViewModel: Codable, Hashable, Identifiable {
    static let formatter = RelativeDateTimeFormatter()
    
    let id: Int
    let comment: Comment
    let indendation: Int
    let parent: CommentViewModel?
    let by: String
    let relativeTimeString: String
    
    var expanded: Bool = true
    var children: [CommentViewModel] = []
    
    var isAnimating: Bool = false
    
    init(comment: Comment, indendation: Int, parent: CommentViewModel?) {
        self.id = comment.id
        self.comment = comment
        self.indendation = indendation
        self.parent = parent
        self.by = comment.by
        self.relativeTimeString = CommentViewModel.formatter.localizedString(for: comment.time, relativeTo: Date())
    }
    
    static func == (lhs: CommentViewModel, rhs: CommentViewModel) -> Bool {
        return lhs.comment == rhs.comment &&
               lhs.indendation == rhs.indendation &&
               lhs.parent == rhs.parent
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(comment)
        hasher.combine(indendation)
        hasher.combine(parent)
    }
}

extension CommentViewModel {
    static func fakeComment() -> CommentViewModel {
        CommentViewModel(comment: Comment(id: 1234, by: "person", kids: nil, parent: 1234, text: "asdf", time: Date()), indendation: 0, parent: nil)
    }
}
