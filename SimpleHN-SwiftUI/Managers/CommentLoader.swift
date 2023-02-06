//
//  CommentLoader.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 3/2/2023.
//

import Foundation
import Combine

final class CommentLoader {
    let apiManager = APIManager()
    var userItemCache = [Int: UserItem]()
    
    func traverse(_ comment: Comment) async throws -> CommentLoaderContainer {
        var currentComment = comment
        var loaderContainer = CommentLoaderContainer()
        
        while(loaderContainer.story == nil) {
            let item = try await traverseAux(currentComment)
            
            switch item {
            case let .comment(comment):
                loaderContainer.commentChain.insert(comment, at: 0)
                currentComment = comment
                userItemCache[comment.id] = item

            case let .story(story):
                loaderContainer.story = story
                loaderContainer.commentViewModels = self.processComments(commentChain: loaderContainer.commentChain)
                userItemCache[story.id] = item
            }
        }
        
        return loaderContainer
    }
    
    // MARK: -
    private func traverseAux(_ comment: Comment) async throws -> UserItem {
        if let cachedParent = userItemCache[comment.parent] {
            return cachedParent
        } else {
            return try await apiManager.loadUserItem(id: comment.parent)
        }
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
