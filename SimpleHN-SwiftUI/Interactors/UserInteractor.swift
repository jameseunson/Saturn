//
//  UserInteractor.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 13/1/2023.
//

import Combine
import Foundation

final class UserInteractor: Interactor, InfiniteScrollViewLoading {
    @Published var user: User?
    @Published var items: Array<UserItemViewModel> = []
    @Published var readyToLoadMore: Bool = false
    @Published var itemsRemainingToLoad: Bool = true
    
    private let username: String
    private let apiManager = APIManager()
    private let pageLength = 10
    
    private var currentPage: Int = 0
    private var submittedIds = [Int]()
    private var loadedItems = [Int]()
    
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
        
        loadMoreItems()
    }
    
    func loadMoreItems() {
        getSubmittedIds()
            .flatMap { _ -> AnyPublisher<[UserItem], Error> in
                guard self.submittedIds.count > 0 else {
                    return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                
                /// Calculate page offsets
                let pageStart = self.currentPage * self.pageLength
                let pageEnd = min(((self.currentPage + 1) * self.pageLength), self.submittedIds.count)
                let idsPage = Array(self.submittedIds[pageStart..<pageEnd])
                
                let stories = idsPage.map { return self.apiManager.loadUserItem(id: $0) }
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
                self.currentPage += 1
                self.loadedItems.append(contentsOf: viewModels.map { $0.id })
                self.readyToLoadMore = true
                
                if self.loadedItems.count == self.submittedIds.count {
                    self.itemsRemainingToLoad = false
                }
            }
            .store(in: &disposeBag)
    }
    
    func getSubmittedIds() -> AnyPublisher<[Int], Never> {
        if self.submittedIds.isEmpty {
            return $user.compactMap { $0?.submitted }
                .handleEvents(receiveOutput: { submitted in
                    self.submittedIds.append(contentsOf: submitted)
                })
                .eraseToAnyPublisher()
        } else {
            return Just(self.submittedIds)
                .eraseToAnyPublisher()
        }
    }
    
    func refreshUser() async {
        Task {
            // TODO: 
        }
    }
}
