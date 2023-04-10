//
//  StoriesListInteractor.swift
//  Saturn
//
//  Created by James Eunson on 8/1/2023.
//

import Combine
import Factory
import Foundation
import SwiftUI

final class StoriesListInteractor: Interactor {
    @Injected(\.apiManager) private var apiManager
    @Injected(\.htmlApiManager) private var htmlApiManager
    @Injected(\.voteManager) private var voteManager
    @Injected(\.networkConnectivityManager) private var networkConnectivityManager
    @Injected(\.settingsManager) private var settingsManager
    @Injected(\.keychainWrapper) private var keychainWrapper
    @Injected(\.availableVoteLoader) private var availableVoteLoader
    @Injected(\.globalErrorStream) private var globalErrorStream
    
    private let pageLength = 10
    private let type: StoryListType
    
    @Published private var currentPage: Int = 0
    @Published private var storyIds = [Int]()
    private var lastRefreshTimestamp: Date?
    
    // MARK: -
    @Published private(set) var stories = [StoryRowViewModel]()
    @Published private(set) var loadingState: LoadingState = .initialLoad
    @Published private(set) var canLoadNextPage: Bool = true
    @Published private(set) var availableVotes: [String: HTMLAPIVote] = [:]
    
    #if DEBUG
    private var displayingSwiftUIPreview = false
    #endif
    
    init(type: StoryListType,
         stories: [StoryRowViewModel] = []) {
        
        self.type = type
        self.stories = stories
        
//        try? APIMemoryResponseCache.default.diskCache.clearCache()
        
        #if DEBUG
        if stories.count > 0 {
            self.displayingSwiftUIPreview = true
        }
        #endif
        super.init()
        
        self.availableVoteLoader.setType(.stories)
        self.lastRefreshTimestamp = settingsManager.date(for: .lastRefreshTimestamp)
    }
    
    override func didBecomeActive() {
        #if DEBUG
        if displayingSwiftUIPreview {
            self.loadingState = .loaded(.cache)
            return
        }
        #endif
        
        if case .initialLoad = loadingState {
            /// Start by loading the offline cache version of the response
            loadNextPage(cacheBehavior: .offlineOnly)
                .flatMap { stories in
                    /// If there is no existing offline cache of the response, hit the network
                    if stories.response.isEmpty {
                        return self.loadNextPage()
                    } else {
                        return Just(stories).setFailureType(to: Error.self).eraseToAnyPublisher()
                    }
                }
                .sink(receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        self.globalErrorStream.addError(error)
                        print(error)
                    }
                }, receiveValue: { response in
                    guard response.source == .cache else {
                        return
                    }
                    self.evaluateRefreshContent()
                })
                .store(in: &disposeBag)
        }
        
        /// Determine whether we can load the next page
        Publishers.CombineLatest3($currentPage, $storyIds, $loadingState)
            .filter { _, _, loadingState in
                if case .loaded = loadingState {
                    return true
                }
                return false
            }
            .map { currentPage, storyIds, loadingState -> Bool in
                guard case .loaded(_) = loadingState else {
                    return false
                }
                return self.networkConnectivityManager.isConnected()
            }
            .receive(on: RunLoop.main)
            .sink { _ in }
            receiveValue: { canLoadNextPage in
                self.canLoadNextPage = canLoadNextPage
            }
            .store(in: &disposeBag)
        
        /// Load voting information about each comment, if the user is logged in (as the user can only vote
        /// if they are logged in)
        if keychainWrapper.isLoggedIn {
            availableVoteLoader.availableVotes
                .receive(on: RunLoop.main)
                .sink { completion in
                    if case let .failure(error) = completion {
                        self.globalErrorStream.addError(error)
                        print(error)
                    }
                } receiveValue: { scoreMap in
                    self.availableVotes = scoreMap

                    for story in self.stories {
                        if let vote = scoreMap[String(story.id)] {
                            story.vote = vote
                        }
                    }
                    self.objectWillChange.send()
                }
                .store(in: &disposeBag)
        }
    }
    
    func loadNextPageFromSource() {
        guard case .loaded(_) = self.loadingState else {
            return
        }
        loadNextPage(cacheBehavior: .ignore)
    }
    
    @MainActor
    func refreshStories(source: APIRefreshingSource) async {
        do {
            self.loadingState = .refreshing(source)
            self.currentPage = 0
            
            self.storyIds.removeAll(keepingCapacity: true)
            self.stories.removeAll(keepingCapacity: true)
            self.availableVoteLoader.clearVotes()
            
            let storyIds = try await apiManager.loadStoryIds(type: self.type, cacheBehavior: .ignore)
            let stories = try await apiManager.loadStories(ids: self.idsForPage(.current, with: storyIds.response), cacheBehavior: .ignore)
            self.availableVoteLoader.evaluateShouldLoadNextStoriesPageAvailableVotes(numberOfStoriesLoaded: stories.response.count)
            
            self.completeLoad(with: stories.response,
                              source: .network)
            
        } catch {
            self.globalErrorStream.addError(StoriesListError.cannotRefresh)
            print(error)
        }
    }
    
    func didTapVote(item: Votable, direction: HTMLAPIVoteDirection) {
        voteManager.vote(item: item, direction: direction) { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    func evaluateRefreshContent() {
        print("evaluateRefreshContent")
        guard self.networkConnectivityManager.isConnected() else {
            return
        }
         
         /// If last refresh was within 10 minutes, do not refresh
         if let lastRefreshTimestamp = self.lastRefreshTimestamp,
            let thresholdTimestamp = Calendar.current.date(byAdding: .minute, value: -10, to: Date()),
            lastRefreshTimestamp > thresholdTimestamp {
             return
         }
        
        /// Conditions are met to refresh, begin refresh
        Task {
            await refreshStories(source: .autoRefresh)
        }
    }
    
    // MARK: -
    @discardableResult
    private func loadNextPage(cacheBehavior: CacheBehavior = .default) -> AnyPublisher<APIResponse<[Story]>, Error> {
        Future { [weak self] promise in
            guard let self else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                switch self.loadingState {
                case .loadingMore:
                    return
                case .loaded, .failed:
                    self.loadingState = .loadingMore
                case .initialLoad, .refreshing:
                    // fallthrough
                    break
                }
            }
            
            self.getStoryIds(cacheBehavior: cacheBehavior)
                .flatMap { ids -> AnyPublisher<[APIResponse<Story>], Error> in
                    return self.apiManager.loadStories(ids: self.idsForPage(.current, with: ids), cacheBehavior: cacheBehavior)
                }
                .receive(on: RunLoop.main)
                .sink { completion in
                    if case let .failure(error) = completion {
                        print(error)
                        self.loadingState = .failed
                        self.globalErrorStream.addError(error)
                        promise(.failure(error))
                    }

                } receiveValue: { stories in
                    print("loadNextPage receiveValue")
                    
                    /// Handle loading stories
                    var source: APIResponseLoadSource = .network
                    stories.forEach { if $0.source == .cache { source = .cache } }
                    
                    /// Complete load
                    self.completeLoad(with: stories.map { $0.response }, source: source)
                    promise(.success(APIResponse(response: stories.map { $0.response },
                                                 source: source)))
                }
                .store(in: &self.disposeBag)
        }
        .eraseToAnyPublisher()
    }
    
    private func getStoryIds(cacheBehavior: CacheBehavior = .default) -> AnyPublisher<[Int], Error> {
        Future { [weak self] promise in
            guard let self else { return }
            
            self.apiManager.loadStoryIds(type: self.type, cacheBehavior: cacheBehavior)
                .receive(on: RunLoop.main)
                .sink { completion in
                    if case let .failure(error) = completion {
                        self.globalErrorStream.addError(error)
                        promise(.failure(error))
                    }
                } receiveValue: { ids in
                    self.storyIds.append(contentsOf: ids.response)
                    promise(.success(ids.response))
                }
                .store(in: &self.disposeBag)
            
        }.eraseToAnyPublisher()
    }
    
    /// Calculate page offsets
    private func idsForPage(_ page: IDPage = .current, with ids: [Int]) -> [Int] {
        let pageNumber: Int
        if case let .page(number) = page {
            pageNumber = number
        } else {
            pageNumber = self.currentPage
        }
        let pageStart = pageNumber * self.pageLength
        let pageEnd = min(((pageNumber + 1) * self.pageLength), ids.count)
        if pageStart > pageEnd { return [] }
        
        let idsPage = Array(ids[pageStart..<pageEnd])
        
        return idsPage
    }
    
    private func completeLoad(with stories: [Story], source: APIResponseLoadSource) {
        /// Handle stories
        let viewModels = stories.map { StoryRowViewModel(story: $0) }
        self.stories.append(contentsOf: viewModels)
        
        for viewModel in viewModels {
            if keychainWrapper.isLoggedIn,
               let vote = self.availableVotes[String(viewModel.id)] {
                viewModel.vote = vote
            }
        }
        availableVoteLoader.evaluateShouldLoadNextStoriesPageAvailableVotes(numberOfStoriesLoaded: self.stories.count)
        
        /// Handle scoremap (if exists)
        for story in self.stories {
            if story.vote == nil,
               let vote = self.availableVotes[String(story.id)] {
                story.vote = vote
            }
        }

        /// Housekeeping after update
        self.loadingState = .loaded(source)
        self.currentPage += 1
        
        if source == .network {
            let timestamp = Date()
            settingsManager.set(value: .date(timestamp), for: .lastRefreshTimestamp)
            self.lastRefreshTimestamp = timestamp
        }
    }
}

enum IDPage: Equatable {
    case current
    case page(Int)
}

enum StoriesListError: Error {
    case cannotRefresh
    
    var errorDescription: String? {
        switch self {
        case .cannotRefresh:
            return NSLocalizedString(
                "Could not refresh stories list. Please check your connection and try again later.",
                comment: ""
            )
        }
    }
}
