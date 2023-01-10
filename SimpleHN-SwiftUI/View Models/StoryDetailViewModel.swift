//
//  StoryDetailViewModel.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 9/1/2023.
//

import Foundation
import SwiftUI

final class StoryDetailViewModel: ViewModel {
//    @Published var comments: LoadableResource<[CommentViewModel]> = .loading
    @Published var comments: Array<CommentViewModel> = []
    
    var loadingState: LoadingState = .initialLoad
    
    let story: Story
    let apiManager = APIManager()
    
    let initialCommentLoadLimit = 5
    var commentsLoaded = 0
    var topLevelComments = [CommentViewModel]()
    
    init(story: Story) {
        self.story = story
    }
    
    override func didBecomeActive() {
        if case .initialLoad = loadingState {
            loadComments()
        }
    }
    
    func loadComments() {
        guard let kids = story.kids else { return }
        
        for kid in kids {
            traverse(kid)
        }
    }
    
    func traverse(_ rootCommentId: Int, parent: CommentViewModel? = nil, indentation: Int = 0) {
        apiManager.loadComment(id: rootCommentId)
            .receive(on: DispatchQueue.global())
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
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
            self.commentsLoaded += 1
            DispatchQueue.main.async {
                self.comments.append(viewModel)
                print(self.comments.count)
            }
            
            if let kids = comment.kids {
                for kid in kids {
                    self.traverse(kid, parent: viewModel, indentation: indentation + 1)
                }
            }
        }
        .store(in: &disposeBag)
    }
    
    func refreshComments() {
        
    }
}
