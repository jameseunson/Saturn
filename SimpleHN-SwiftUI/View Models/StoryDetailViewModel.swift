//
//  StoryDetailViewModel.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 9/1/2023.
//

import Foundation
import SwiftUI
import UIKit

final class StoryDetailViewModel: ViewModel {
//    @Published var comments: LoadableResource<[CommentViewModel]> = .loading
    @Published var comments: Array<CommentViewModel> = []
    
    var loadingState: LoadingState = .initialLoad
    
    let story: Story
    let apiManager = APIManager()
    
    @Published var commentsLoaded = 0
    var topLevelComments = [CommentViewModel]()
    
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
    
    /// Visit each leaf and create a view model, appending to the parent's `children` property
    func traverse(_ rootCommentId: Int, parent: CommentViewModel? = nil, indentation: Int = 0) {
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
    func flatten() -> [CommentViewModel] {
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
    
    func refreshComments() {
        
    }
}
