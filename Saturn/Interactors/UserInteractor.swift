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
    private var scoreMap = [Int: Int]()
    
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
                    .map { ($0, ids) }
                    .eraseToAnyPublisher()
            }
            .receive(on: RunLoop.main)
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                }
                
            } receiveValue: { items, ids in
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
            
            self.currentPage = 0
            let ids = idsForCurrentPage(with: user.submitted)
            let items = try await self.apiManager.loadUserItems(ids: ids)
            
            DispatchQueue.main.async {
                self.readyToLoadMore = true
                self.itemsRemainingToLoad = true
                self.completeLoad(with: items, idsForPage: ids)
            }
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
    
    func completeLoad(with items: [UserItem], idsForPage: [Int]) {
        Task { @MainActor in
            var viewModels = [UserItemViewModel]()
            for item in items {
                switch item {
                case let .comment(comment):
                    viewModels.append(UserItemViewModel.comment(CommentViewModel(comment: comment, indendation: 0, parent: nil)))
                case let .story(story):
                    viewModels.append(UserItemViewModel.story(StoryRowViewModel(story: story)))
                }
            }
            
            /// Load scores for each comment, if logged in
            if SaturnKeychainWrapper.shared.isLoggedIn {
                let scoreMap = try await self.htmlApiManager.loadPointsForSubmissions(page: self.currentPage)
                scoreMap.forEach { (key, value) in self.scoreMap[key] = value }

                for (i, item) in viewModels.enumerated() {
                    guard case let .comment(model) = item,
                          let score = self.scoreMap[model.id],
                          model.score == nil else {
                        continue
                    }
                    model.score = score
                    viewModels[i] = UserItemViewModel.comment(model)
                }
            }
            
            self.items.append(contentsOf: viewModels)
            self.completeLoadIncrementPage(idsForPage: idsForPage)
        }
    }
    
    private func completeLoadIncrementPage(idsForPage: [Int]) {
        self.currentPage += 1
        self.itemsLoaded += idsForPage.count
        self.readyToLoadMore = true
        
        if self.itemsLoaded == self.submittedIds.count {
            self.itemsRemainingToLoad = false
        }
    }
}
