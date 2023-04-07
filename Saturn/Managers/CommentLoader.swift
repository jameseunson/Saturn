//
//  CommentLoader.swift
//  Saturn
//
//  Created by James Eunson on 3/2/2023.
//

import Foundation
import Combine

protocol CommentLoading: AnyObject {
    func traverse(_ comment: Comment) async throws -> CommentLoaderContainer
}

actor CommentLoader: CommentLoading {
    let apiManager = APIManager()
    private var activeTasks = [Int: Task<UserItem, Error>]()
    
    func traverse(_ comment: Comment) async throws -> CommentLoaderContainer {
        var currentComment = comment
        var loaderContainer = CommentLoaderContainer()
        
        while(loaderContainer.story == nil) {
            let item = try await traverseAux(currentComment)
            
            switch item {
            case let .comment(comment):
                loaderContainer.commentChain.insert(comment, at: 0)
                currentComment = comment

            case let .story(story):
                loaderContainer.story = story
                loaderContainer.commentViewModels = self.processComments(commentChain: loaderContainer.commentChain)
            }
        }
        
        return loaderContainer
    }
    
    // MARK: -
    private func traverseAux(_ comment: Comment) async throws -> UserItem {
        if let existingTask = activeTasks[comment.parent] {
            return try await existingTask.value
        }
        let task = Task<UserItem, Error> {
            let userItem = try await apiManager.loadUserItem(id: comment.parent)
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
    var commentChain: [Comment] = []
    var commentViewModels: [CommentViewModel] = []
    var story: Story?
}
