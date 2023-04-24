//
//  CommentLoader.swift
//  Saturn
//
//  Created by James Eunson on 3/2/2023.
//

import Foundation
import Combine

protocol CommentLoading: AnyObject {
    func traverse(_ comment: Comment, cacheBehavior: CacheBehavior) async throws -> CommentLoaderContainer
}

actor CommentLoader: CommentLoading {
    let apiManager = APIManager()
    private var activeTasks = [Int: Task<UserItem, Error>]()
    
    func traverse(_ focusedComment: Comment, cacheBehavior: CacheBehavior) async throws -> CommentLoaderContainer {
        var currentComment = focusedComment
        var loaderContainer = CommentLoaderContainer(focusedComment: focusedComment)
        
        while(loaderContainer.story == nil) {
            let item = try await traverseAux(currentComment, cacheBehavior: cacheBehavior)
            
            switch item {
            case let .comment(comment):
                loaderContainer.commentChain.insert(comment, at: 0)
                currentComment = comment

            case let .story(story):
                loaderContainer.story = story
                loaderContainer.commentViewModels = self.processComments(commentChain: loaderContainer.commentChain)
                
            case .deleted:
                throw CommentLoaderError.deleted(focusedComment.id)
            }
        }
        
        return loaderContainer
    }
    
    // MARK: -
    private func traverseAux(_ comment: Comment, cacheBehavior: CacheBehavior) async throws -> UserItem {
        if let existingTask = activeTasks[comment.parent] {
            return try await existingTask.value
        }
        let task = Task<UserItem, Error> {
            let userItem = try await apiManager.loadUserItem(id: comment.parent, cacheBehavior: cacheBehavior)
            activeTasks[comment.parent] = nil
            
            return userItem
        }
        return try await task.value
    }

    private func processComments(commentChain: [Comment]) -> [CommentViewModel] {
        var output = [CommentViewModel]()
        var parent: CommentViewModel?
        for (i, comment) in commentChain.enumerated() {
            let model = CommentViewModel(comment: comment, indendation: i, parent: parent)
            output.append(model)
            
            parent = model
        }
        return output
    }
}

struct CommentLoaderContainer {
    let focusedComment: Comment /// Comment from which we traverse upwards to the story
    var commentChain: [Comment] = []
    var commentViewModels: [CommentViewModel] = []
    var story: Story?
}

extension CommentLoading {
    func traverse(_ comment: Comment, cacheBehavior: CacheBehavior = .default) async throws -> CommentLoaderContainer {
        try await traverse(comment, cacheBehavior: cacheBehavior)
    }
}

enum CommentLoaderError: Error {
    case deleted(Int)
}
