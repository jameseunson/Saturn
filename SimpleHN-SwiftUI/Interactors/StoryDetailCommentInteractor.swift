//
//  StoryDetailCommentInteractor.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 20/1/2023.
//

import Foundation
import Combine

final class StoryDetailCommentInteractor: Interactor {
    @Published private(set) var story: Story?
    @Published private(set) var comments: Array<CommentViewModel> = []
    @Published private(set) var focusedCommentViewModel: CommentViewModel?
    
    private let focusedComment: Comment
    
    private let apiManager = APIManager()
    private var commentChain: [Comment]
    
    init(focusedComment viewModel: CommentViewModel) {
        self.focusedComment = viewModel.comment
        self.commentChain = [focusedComment]
    }
    
    override func didBecomeActive() {
        traverse(focusedComment)
    }
    
    func traverse(_ comment: Comment) {
        apiManager.loadUserItem(id: comment.parent)
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                }
            } receiveValue: { item in
                switch item {
                case let .comment(comment):
                    self.commentChain.insert(comment, at: 0)
                    self.traverse(comment)
                    
                case let .story(story):
                    self.story = story
                    
                    self.processComments()
                }
            }
            .store(in: &disposeBag)
    }
    
    func processComments() {
        var parent: CommentViewModel?
        for (i, comment) in commentChain.enumerated() {
            let model = CommentViewModel(comment: comment, indendation: i, parent: parent)
            if i == 0 {
                self.focusedCommentViewModel = model
            }
            comments.append(model)
            
            parent = model
        }
    }
}
