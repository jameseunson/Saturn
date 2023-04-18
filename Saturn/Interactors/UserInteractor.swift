//
//  UserInteractor.swift
//  Saturn
//
//  Created by James Eunson on 13/1/2023.
//

import Combine
import Foundation
import Factory

final class UserInteractor: Interactor, InfiniteScrollViewLoading {
    @Injected(\.apiManager) private var apiManager
    @Injected(\.htmlApiManager) private var htmlApiManager
    @Injected(\.commentLoader) private var commentLoader
    @Injected(\.keychainWrapper) private var keychainWrapper
    @Injected(\.globalErrorStream) private var globalErrorStream
    @Injected(\.networkConnectivityManager) private var networkConnectivityManager
    @Injected(\.commentScoreLoader) private var commentScoreLoader
    
    @Published private(set) var user: User?
    @Published private(set) var items: LoadableResource<[UserItemViewModel]> = .notLoading
    @Published private(set) var readyToLoadMore: Bool = false
    @Published private(set) var itemsRemainingToLoad: Bool = true
    
    private let username: String
    private let pageLength = 10
    
    private var currentPage: Int = 0
    private var submittedIds = [Int]()
    private var scoreMap = [String: Int]()
    private var itemsAccumulator = [UserItemViewModel]()
    private var lastRefreshTimestamp: Date?
    
    var commentContexts = CurrentValueSubject<[Int: CommentLoaderContainer], Never>([:])
    @Published private var itemsLoaded = 0
    
    init(username: String) {
        self.username = username
    }
    
    init(user: User) {
        self.user = user
        self.username = user.id
    }
    
    override func didBecomeActive() {
        self.items = .loading
        
        if user == nil {
            apiManager.loadUser(id: username, cacheBehavior: .offlineOnly)
                .catch { _ in
                    return Empty().eraseToAnyPublisher()
                }
                .handleEvents(receiveOutput: { user in
                    DispatchQueue.main.async {
                        self.user = user.response
                    }
                })
                .flatMap { user -> AnyPublisher<APIResponse<User>, Error> in
                    if self.networkConnectivityManager.isConnected() {
                        return self.apiManager.loadUser(id: self.username, cacheBehavior: .default)
                    } else {
                        return Just(user).setFailureType(to: Error.self).eraseToAnyPublisher()
                    }
                }
                .receive(on: RunLoop.main)
                .sink { completion in
                    if case let .failure(error) = completion {
                        self.globalErrorStream.addError(error)
                        print(error)
                    }
                } receiveValue: { output in
                    self.user = output.response
                    self.loadMoreItems()
                }
                .store(in: &disposeBag)
        }
        
        if shouldLoadCommentScores() {
            commentScoreLoader.scoreMap
                .receive(on: RunLoop.main)
                .sink { completion in
                    if case let .failure(error) = completion {
                        self.globalErrorStream.addError(error)
                        print(error)
                    }
                } receiveValue: { scoreMap in
                    self.scoreMap = scoreMap

                    self.applyScoreMap(scoreMap: scoreMap, items: self.itemsAccumulator)
                    self.objectWillChange.send()
                }
                .store(in: &disposeBag)
        }
    }
    
    func loadCommentChain(from comment: CommentViewModel, cacheBehavior: CacheBehavior = .default) -> AnyPublisher<(CommentViewModel, CommentLoaderContainer), Error> {
        AsyncTools.publisherForAsync {
            return (comment, try await self.commentLoader.traverse(comment.comment, cacheBehavior: cacheBehavior))
        }
    }
    
    func loadMoreItems() {
        loadItems(cacheBehavior: .offlineOnly)
            .handleEvents(receiveOutput: { (items: [UserItem], ids: [Int]) in
                DispatchQueue.main.async { [weak self] in
                    self?.completeLoad(with: items, idsForPage: ids)
                }
            })
            .flatMap({ (result: ([UserItem], [Int])) in
                if self.networkConnectivityManager.isConnected() {
                    return self.loadItems(cacheBehavior: .default)
                } else {
                    return Just(result).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
            })
            .receive(on: RunLoop.main)
            .sink { completion in
                if case let .failure(error) = completion {
                    self.globalErrorStream.addError(error)
                    print(error)
                }

            } receiveValue: { items, ids in
                self.completeLoad(with: items, idsForPage: ids)
            }
            .store(in: &disposeBag)
    }
    
    func getSubmittedIds() -> AnyPublisher<[Int], Never> {
        if self.submittedIds.isEmpty {
            return $user.map { $0?.submitted ?? [] }
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
            guard let user else { return }
            
            /// Abort refresh if last refresh occurred within 60 seconds of most recent load
            /// Avoids the app potentially placing too much load on HN
            if let lastRefreshTimestamp,
               lastRefreshTimestamp > Date().addingTimeInterval(-60) {
                    return
            }
            self.readyToLoadMore = false
            
            self.currentPage = 0
            self.user = try await apiManager.loadUser(id: username, cacheBehavior: .ignore).response
            let ids = idsForCurrentPage(with: user.submitted ?? [])
            let items = try await self.apiManager.loadUserItems(ids: ids, cacheBehavior: .ignore)
            
            DispatchQueue.main.async {
                self.items = .notLoading
                self.itemsAccumulator.removeAll()
                self.itemsLoaded = 0
                self.submittedIds.removeAll()
                self.scoreMap.removeAll()
                
                self.commentContexts.send([:])
                self.commentScoreLoader.clearScores()
            }
            
            if self.shouldLoadCommentScores() {
                self.commentScoreLoader.evaluateShouldLoadScoresForLoggedInUserComments()
            }
            
            DispatchQueue.main.async {
                self.completeLoad(with: items, idsForPage: ids, ignoreCache: true)
            }
        }
    }
    
    
    func completeLoad(with items: [UserItem], idsForPage: [Int], ignoreCache: Bool = false) {
        var viewModels = [UserItemViewModel]()
        for item in items {
            switch item {
            case let .comment(comment):
                viewModels.append(UserItemViewModel.comment(CommentViewModel(comment: comment, indendation: 0, parent: nil)))
            case let .story(story):
                viewModels.append(UserItemViewModel.story(StoryRowViewModel(story: story)))
            case .deleted:
                break
            }
        }
        
        self.itemsAccumulator.append(contentsOf: viewModels)
        self.items = .loaded(response: itemsAccumulator)
        self.currentPage += 1
        self.itemsLoaded += idsForPage.count
        self.readyToLoadMore = true
        
        if self.itemsLoaded == self.submittedIds.count {
            self.itemsRemainingToLoad = false
        }
        if self.shouldLoadCommentScores() {
            self.commentScoreLoader.evaluateShouldLoadScoresForLoggedInUserComments(numberOfCommentsLoaded: itemsAccumulator.count)
        }
        self.loadContexts(items: viewModels, ignoreCache: ignoreCache)
        
        self.lastRefreshTimestamp = Date()
    }
    
    // MARK: -
    private func loadItems(cacheBehavior: CacheBehavior = .default) -> AnyPublisher<([UserItem], [Int]), Error> {
        return getSubmittedIds()
            .flatMap { ids -> AnyPublisher<([UserItem], [Int]), Error> in
                if ids.isEmpty { return Just(([UserItem](), ids)).setFailureType(to: Error.self).eraseToAnyPublisher() }
                
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
            .eraseToAnyPublisher()
    }
    
    private func publishers(for models: [UserItemViewModel], cacheBehavior: CacheBehavior = .default) -> [AnyPublisher<(CommentViewModel, CommentLoaderContainer), Error>] {
        return models.compactMap {
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
        .map { self.loadCommentChain(from: $0, cacheBehavior: cacheBehavior) }
    }
    
    private func handleCommentContextLoad(_ item: (CommentViewModel, CommentLoaderContainer)) {
        var mutableContexts = self.commentContexts.value

        let (commentViewModel, container) = item
        mutableContexts[commentViewModel.id] = container

        self.commentContexts.send(mutableContexts)
    }
    
    /// Retrieve context object `CommentLoaderContainer` for each comment
    private func loadContexts(items: [UserItemViewModel], ignoreCache: Bool = false) {
        Just(items)
            .filter { $0.count > 0 }
            .setFailureType(to: Error.self)
            .flatMap { models in
                let publishers = self.publishers(for: models, cacheBehavior: ignoreCache ? .ignore : .offlineOnly)
                if publishers.count > 0 {
                    return Publishers.MergeMany(publishers).eraseToAnyPublisher()
                } else {
                    return Empty().eraseToAnyPublisher()
                }
            }
            .handleEvents(receiveOutput: { item in
                if ignoreCache { return }
                DispatchQueue.main.async { [weak self] in
                    self?.handleCommentContextLoad(item)
                }
            })
            .flatMap { (item: (CommentViewModel, CommentLoaderContainer)) -> AnyPublisher<(CommentViewModel, CommentLoaderContainer), Error> in
                if ignoreCache {
                    return Just(item).setFailureType(to: Error.self).eraseToAnyPublisher()
                } else {
                    return self.loadCommentChain(from: item.0)
                }
            }
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    self.globalErrorStream.addError(error)
                    print(error)
                }
            }, receiveValue: { item in
                self.handleCommentContextLoad(item)
            })
            .store(in: &disposeBag)
    }
    
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
        return keychainWrapper.isLoggedIn &&
           self.username == keychainWrapper.retrieve(for: .username)
    }
    
    /// Sets the score for every comment we have a score for
    private func applyScoreMap(scoreMap: [String: Int], items: [UserItemViewModel]) {
        scoreMap.forEach { (key, value) in self.scoreMap[key] = value }
        
        for item in items {
            guard case let .comment(model) = item,
                  let score = self.scoreMap[String(model.id)] else {
                continue
            }
            model.score = score
        }
    }
    
    private func isLoadingLoggedInUser(_ username: String) -> Bool {
        if keychainWrapper.isLoggedIn,
           let loggedInUsername = keychainWrapper.retrieve(for: .username),
           loggedInUsername == username {
            return true
        }
        return false
    }
}
