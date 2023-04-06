//
//  UserInteractor.swift
//  Saturn
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
    private var scoreMap = [String: Int]()
    
    var commentContexts = CurrentValueSubject<[Int: CommentLoaderContainer], Never>([:])
    @Published private var itemsLoaded = 0
    
    private let apiManager = APIManager()
    private let commentLoader = CommentLoader()
    private let htmlApiManager = HTMLAPIManager()
    
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
        
        /// Retrieve context object `CommentLoaderContainer` for each comment
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
            }, receiveValue: { item in
                var mutableContexts = self.commentContexts.value
                
                let (commentViewModel, container) = item
                mutableContexts[commentViewModel.id] = container
                
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
            .flatMap { ids -> AnyPublisher<([UserItem], [Int]), Error> in
                let ids = self.idsForCurrentPage(with: ids)
                return self.apiManager.loadUserItems(ids: ids)
                    .map { userItems in
                        let sortedUserItems = userItems.sorted { lhs, rhs in
                            return lhs.time > rhs.time
                        }
                        return (sortedUserItems, ids)
                    }
                    .eraseToAnyPublisher()
            }
            .flatMap { items, ids -> AnyPublisher<([UserItem], [Int], [String: Int]), Error> in
                if self.shouldLoadCommentScores() {
                    return self.htmlApiManager.loadScoresForLoggedInUserComments(startFrom: self.scoreMapStartFrom())
                        .map { (items, ids, $0) }
                        .eraseToAnyPublisher()
                } else {
                    return Just((items, ids, [String:Int]())).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
            }
            .receive(on: RunLoop.main)
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                }

            } receiveValue: { items, ids, scoreMap in
                if self.shouldLoadCommentScores() {
                    self.applyScoreMap(scoreMap: scoreMap, items: items)
                }
                self.completeLoad(with: items, idsForPage: ids)
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
            guard let user else {
                return
            }
            
            DispatchQueue.main.async {
                self.items.removeAll()
            }
            self.itemsLoaded = 0
            self.submittedIds.removeAll()
            self.scoreMap.removeAll()
            
            self.currentPage = 0
            let ids = idsForCurrentPage(with: user.submitted)
            let items = try await self.apiManager.loadUserItems(ids: ids)
            
            if self.shouldLoadCommentScores() {
                let scoreMap = try await self.htmlApiManager.loadScoresForLoggedInUserComments()
                applyScoreMap(scoreMap: scoreMap, items: items)
            }
            
            DispatchQueue.main.async {
                self.completeLoad(with: items, idsForPage: ids)
            }
        }
    }
    
    
    func completeLoad(with items: [UserItem], idsForPage: [Int]) {
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
        self.itemsLoaded += idsForPage.count
        self.readyToLoadMore = true
        
        if self.itemsLoaded == self.submittedIds.count {
            self.itemsRemainingToLoad = false
        }
    }
    
    // MARK: -
    /// Calculate page offsets
    private func idsForCurrentPage(with ids: [Int]) -> [Int] {
        let pageStart = self.currentPage * self.pageLength
        let pageEnd = min(((self.currentPage + 1) * self.pageLength), self.submittedIds.count)
        let idsPage = Array(self.submittedIds[pageStart..<pageEnd])
        
        return idsPage
    }
    
    /// Comment scores should only be loaded if the user is logged in and the user in context is the logged in user
    /// as this is the only user we have the ability to retrieve comment scores for
    private func shouldLoadCommentScores() -> Bool {
        return SaturnKeychainWrapper.shared.isLoggedIn &&
           self.user?.id == SaturnKeychainWrapper.shared.retrieve(for: .username)
    }
    
    /// Sets the score for every comment we have a score for
    private func applyScoreMap(scoreMap: [String: Int], items: [UserItem]) {
        scoreMap.forEach { (key, value) in self.scoreMap[key] = value }
        
        for item in items {
            guard case let .comment(model) = item,
                  let score = self.scoreMap[String(model.id)] else {
                continue
            }
            model.score = score
        }
    }
    
    /// The HN URL for comments requires setting an offset passed via the `next` url parameter
    /// We can calculate the correct `next` value by looking at the last comment and subtracting 1 from the id
    private func scoreMapStartFrom() -> Int? {
        var startFrom: Int? = nil
        if !self.items.isEmpty,
           let last = self.items.last {
            startFrom = max(last.id-1, 0)
        }
        return startFrom
    }
}
