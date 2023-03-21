//
//  CommentViewModel.swift
//  Saturn
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
    var totalChildCount = 0
    var score: Int?
    
    var isAnimating: CommentAnimatingState = .none
    
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
        let comment = Comment(id: 1234, by: "person", kids: nil, parent: 1234, text: "asdf", time: Date())

        comment.processedText = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc sit amet nibh et purus consequat consectetur. Vivamus et mi quis risus dictum dictum. In sed orci quis augue efficitur varius sollicitudin nec ipsum. Donec non magna quis dui elementum facilisis quis lacinia diam. Sed tortor nibh, luctus convallis dictum vel, ullamcorper a tellus."
        comment.processedTextHeight = 200
        
        return CommentViewModel(comment: comment, indendation: 0, parent: nil)
    }
    
    static func fakeCommentWithScore() -> CommentViewModel {
        let comment = fakeComment()
        comment.score = 3
        return comment
    }
}

enum CommentAnimatingState: Codable {
    case expanding
    case collapsing
    case none
}
