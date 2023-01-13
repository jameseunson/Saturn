//
//  CommentViewModel.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 10/1/2023.
//

import Foundation

final class CommentViewModel: Codable, Hashable, Identifiable {
    let id: Int
    let comment: Comment
    let indendation: Int
    let parent: CommentViewModel?
    let by: String
    
    var expanded: Bool = true
    var children: [CommentViewModel] = []
    
    init(comment: Comment, indendation: Int, parent: CommentViewModel?) {
        self.id = comment.id
        self.comment = comment
        self.indendation = indendation
        self.parent = parent
        self.by = comment.by
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
