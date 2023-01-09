//
//  StoryDetailViewModel.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 9/1/2023.
//

import Foundation

final class StoryDetailViewModel: ViewModel {
    @Published var comments: LoadableResource<[Comment]> = .loading
    
    let story: Story
    let apiManager = APIManager()
    
    var commentLoadQueue = [Int]()
    
    init(story: Story) {
        self.story = story
    }
    
    override func didBecomeActive() {
        if case .loading = comments {
            loadComments()
        }
    }
    
    func loadComments() {
        guard let kids = story.kids else { return }
        commentLoadQueue.append(contentsOf: kids)
        
        guard let commentId = commentLoadQueue.first else {
            return
        }
        
        let comment = apiManager.loadComment(id: commentId)
        comment.sink { _ in
            
        } receiveValue: { comment in
            print(comment)
        }
        .store(in: &disposeBag)

    }
}
