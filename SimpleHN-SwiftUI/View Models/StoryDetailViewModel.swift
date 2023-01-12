//
//  StoryDetailViewModel.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 9/1/2023.
//

import Foundation
import SwiftUI
import UIKit

enum CommentExpandedState {
    case expanded
    case collapsed
    case hidden
}

final class StoryDetailViewModel: ViewModel {
    @Published var comments: Array<CommentViewModel> = []
    @Published var commentsExpanded: Dictionary<CommentViewModel, CommentExpandedState> = [:]
    
    private let story: Story
    private let apiManager = APIManager()
    
    @Published private var commentsLoaded = 0
    private var topLevelComments = [CommentViewModel]()
    private var loadingState: LoadingState = .initialLoad
    
    init(story: Story) {
        self.story = story
    }
    
    override func didBecomeActive() {
        if case .initialLoad = loadingState {
            loadComments()
        }
        
        /// Workaround for the fact that we have no idea when loading is complete
        /// and the backend always returns fewer comments than is indicated by
        /// `descendants` on the Story model
        $commentsLoaded
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .prefix(1)
            .sink { _ in
                self.comments = self.flatten()
        }
        .store(in: &disposeBag)
    }
    
    func loadComments() {
        guard let kids = story.kids else { return }
        
        for kid in kids {
            traverse(kid)
        }
    }
    
    func refreshComments() {
        
    }
    
    func updateExpanded(_ expanded: Dictionary<CommentViewModel, CommentExpandedState>, for comment: CommentViewModel, _ set: CommentExpandedState) {
        commentsExpanded = expanded
        
        var queue = Array<CommentViewModel>()
        queue.append(contentsOf: comment.children)
        
        while(!queue.isEmpty) {
            let comment = queue.removeFirst()
            queue.insert(contentsOf: comment.children, at: 0)
            
            if set == .collapsed {
                commentsExpanded[comment] = .hidden
            } else {
                commentsExpanded[comment] = .expanded
            }
        }
    }
    
    // MARK: -
    /// Visit each leaf and create a view model, appending to the parent's `children` property
    private func traverse(_ rootCommentId: Int, parent: CommentViewModel? = nil, indentation: Int = 0) {
        apiManager.loadComment(id: rootCommentId)
            .receive(on: DispatchQueue.global())
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                    DispatchQueue.main.async {
                        self.commentsLoaded += 1
                    }
                }
            
        } receiveValue: { comment in
            let viewModel = CommentViewModel(comment: comment,
                                             indendation: indentation,
                                             parent: parent)
            if let parent {
                parent.children.append(viewModel)
            } else {
                self.topLevelComments.append(viewModel)
            }
            
            DispatchQueue.main.async {
                self.commentsExpanded[viewModel] = .expanded
                self.commentsLoaded += 1
            }
            
            if let kids = comment.kids {
                for kid in kids {
                    self.traverse(kid, parent: viewModel, indentation: indentation + 1)
                }
            }
        }
        .store(in: &disposeBag)
    }
    
    /// Once the comments are loaded, walk the tree and construct a flat representation
    /// for display as a list
    private func flatten() -> [CommentViewModel] {
        var queue = Array<CommentViewModel>()
        queue.append(contentsOf: topLevelComments)
        
        var flat = Array<CommentViewModel>()
        
        while(!queue.isEmpty) {
            let comment = queue.removeFirst()
            flat.append(comment)
            
            queue.insert(contentsOf: comment.children, at: 0)
        }
        
        return flat
    }
}
