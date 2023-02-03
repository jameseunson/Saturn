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
    private let pageLength = 10
    
    private var currentPage: Int = 0
    private var submittedIds = [Int]()
    private var loadedItems = [Int]()
    
    var commentContexts = CurrentValueSubject<[Int: CommentLoaderContainer], Never>([:])
    
    private let apiManager = APIManager()
    private let commentLoader = CommentLoader()
    
    init(username: String) {
        self.username = username
    }
    
    init(user: User) {
        self.user = user
        self.username = user.id
    }
    
    override func didBecomeActive() {
        if user == nil {
            apiManager.loadUser(id: username)
                .receive(on: RunLoop.main)
                .sink { completion in
                    if case let .failure(error) = completion {
                        print(error)
                    }
                    
                } receiveValue: { user in
                    self.user = user
                }
                .store(in: &disposeBag)
        }
        
        $items
            .filter { $0.count > 0 }
            .setFailureType(to: Error.self)
            .flatMap { models in
                let publishers = models.compactMap {
                    /// If we already have a chain object for this comment, don't retrieve it
                    if self.commentContexts.value.keys.contains($0.id) {
                        return nil
                    }
                    if case let .comment(comment) = $0 {
                        return comment
                    } else {
                        return nil
                    }
                }
                .map { self.loadCommentChain(from: $0) }
                
                if publishers.count > 0 {
                    return Publishers.MergeMany(publishers)
                        .collect()
                        .eraseToAnyPublisher()
                } else {
                    return Empty()
                        .eraseToAnyPublisher()
                }
            }
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    print(error)
                    // TODO: 
                }
            }, receiveValue: { output in
                var mutableContexts = self.commentContexts.value
                for item in output {
                    let (commentViewModel, container) = item
                    mutableContexts[commentViewModel.id] = container
                }
                self.commentContexts.send(mutableContexts)
            })
            .store(in: &disposeBag)
        
        loadMoreItems()
    }
    
    func loadCommentChain(from comment: CommentViewModel) -> AnyPublisher<(CommentViewModel, CommentLoaderContainer), Error> {
        return Future { [weak self] promise in
            guard let self else { return }
            
            Task {
                do {
                    let output = try await self.commentLoader.traverse(comment.comment)
                    promise(.success((comment, output)))
                } catch let error {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
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
            .receive(on: RunLoop.main)
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
