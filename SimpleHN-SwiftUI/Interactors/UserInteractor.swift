//
//  UserInteractor.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 13/1/2023.
//

import Combine
import Foundation

final class UserInteractor: Interactor {
    @Published var user: User?
    @Published var items: Array<UserItemViewModel> = []
    
    let username: String
    let apiManager = APIManager()
    
    init(username: String) {
        self.username = username
    }
    
    override func didBecomeActive() {
        apiManager.loadUser(id: username)
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                }
                
            } receiveValue: { user in
                self.user = user
            }
            .store(in: &disposeBag)
        
        $user.compactMap { $0 }
            .flatMap { user in
                let stories = user.submitted[0..<10].map { return self.apiManager.loadUserItem(id: $0) }
                return Publishers.MergeMany(stories)
                    .collect()
                    .eraseToAnyPublisher()
            }
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                }
                
            } receiveValue: { items in
                var viewModels = [UserItemViewModel]()
                for item in items {
                    switch item {
                    case let .comment(comment):
                        viewModels.append(UserItemViewModel.comment(CommentViewModel(comment: comment, indendation: 0, parent: nil)))
                    case let .story(story):
                        viewModels.append(UserItemViewModel.story(StoryRowViewModel(story: story)))
                    }
                }
                self.items.append(contentsOf: viewModels)
            }
            .store(in: &disposeBag)
    }
}
