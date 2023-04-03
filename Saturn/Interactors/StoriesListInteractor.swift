//
//  StoriesListInteractor.swift
//  Saturn
//
//  Created by James Eunson on 8/1/2023.
//

import Combine
import Foundation
import SwiftUI

final class StoriesListInteractor: Interactor {
    private let apiManager: APIManaging
    private let pageLength = 10
    private let type: StoryListType
    private let networkConnectivityManager: NetworkConnectivityManaging
    private let htmlApiManager = HTMLAPIManager()
    private let voteManager = VoteManager()
    
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
         stories: [StoryRowViewModel] = [],
         apiManager: APIManaging = APIManager(),
         lastRefreshTimestamp: Date? = SettingsManager.default.date(for: .lastRefreshTimestamp),
         networkConnectivityManager: NetworkConnectivityManaging = NetworkConnectivityManager.instance) {
        
        self.apiManager = apiManager
        self.type = type
        self.stories = stories
        self.lastRefreshTimestamp = lastRefreshTimestamp
        self.networkConnectivityManager = networkConnectivityManager
        
//        try? APIMemoryResponseCache.default.diskCache.clearCache()
        
        #if DEBUG
        if stories.count > 0 {
            self.displayingSwiftUIPreview = true
        }
        #endif
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
                        print(error)
                        // TODO:
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
        /// If online (`loaded(source) == .network`), assumed we always can
        /// If offline (`loaded(source) == .cache`), check whether the next 10 stories
        /// live in the disk cache - if so, we can load
        Publishers.CombineLatest3($currentPage, $storyIds, $loadingState)
            .filter { _, _, loadingState in
                if case .loaded = loadingState {
                    return true
                }
                return false
            }
            .map { currentPage, storyIds, loadingState -> Bool in
                guard case let .loaded(source) = loadingState else {
                    return false
                }
                switch source {
                case .network:
                    return true

                case .cache:
                    if storyIds.count == 0 { return false }

                    let ids = self.idsForPage(.page(self.currentPage + 1), with: storyIds)
                    var availableInCache = true
                    for id in ids {
                        if !self.apiManager.hasCachedResponse(for: id) { availableInCache = false; break }
                    }

                    return availableInCache
                }
            }
            .receive(on: RunLoop.main)
            .sink { _ in }
            receiveValue: { canLoadNextPage in
                self.canLoadNextPage = canLoadNextPage
            }
            .store(in: &disposeBag)
    }
    
    func loadNextPageFromSource() {
        guard case let .loaded(source) = self.loadingState else {
            return
        }
        switch source {
        case .network:
            loadNextPage(cacheBehavior: .ignore)
        case .cache:
            loadNextPage(cacheBehavior: .offlineOnly)
        }
    }
    
    @MainActor
    func refreshStories(source: APIRefreshingSource) async {
        do {
            self.loadingState = .refreshing(source)
            self.currentPage = 0
            
            self.storyIds.removeAll(keepingCapacity: true)
            self.stories.removeAll(keepingCapacity: true)
            
            let storyIds = try await apiManager.loadStoryIds(type: self.type, cacheBehavior: .ignore)
            let stories = try await apiManager.loadStories(ids: self.idsForPage(.current, with: storyIds.response), cacheBehavior: .ignore)
            let scoreMap: APIResponse<VoteHTMLParserResponse>
            
            if SaturnKeychainWrapper.shared.isLoggedIn {
                scoreMap = try await htmlApiManager.loadAvailableVotesForStoriesList(page: (self.currentPage / 3), cacheBehavior: .ignore)
            } else {
                scoreMap = APIResponse(response: VoteHTMLParserResponse(scoreMap: [String: HTMLAPIVote](), hasNextPage: false), source: .network)
            }
            
            self.completeLoad(with: stories.response,
                              scoreMap: scoreMap.response.scoreMap,
                              source: .network)
            
        } catch {
            // TODO: Handle error
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
                .flatMap { stories -> AnyPublisher<(APIResponse<VoteHTMLParserResponse>, [APIResponse<Story>]), Error> in
                    if SaturnKeychainWrapper.shared.isLoggedIn {
                        /// Load votes for the current page
                        /// Because we cannot get this from the Firebase API, the HTML 'API' has to be used instead
                        /// which involves scraping the html of news.ycombinator.com
                        /// Firebase pages are 10 items, whereas HTML pages are 30 items, so every 3 Firebase pages a new HTML page is scraped
                        return self.htmlApiManager.loadAvailableVotesForStoriesList(page: (self.currentPage / 3), cacheBehavior: cacheBehavior)
                            .map { ($0, stories) }
                            .eraseToAnyPublisher()
                    } else {
                        /// If not logged in, return an empty dictionary
                        return Just(APIResponse(response: VoteHTMLParserResponse(scoreMap: [String: HTMLAPIVote](), hasNextPage: false), source: .network))
                            .map { ($0, stories) }
                            .setFailureType(to: Error.self)
                            .eraseToAnyPublisher()
                    }
                }
                .receive(on: RunLoop.main)
                .sink { completion in
                    if case let .failure(error) = completion {
                        print(error)
                        self.loadingState = .failed
                        promise(.failure(error))
                    }

                } receiveValue: { scoreMapResult, stories in
                    print("loadNextPage receiveValue")
                    
                    /// Handle loading stories
                    var source: APIResponseLoadSource = .network
                    stories.forEach { if $0.source == .cache { source = .cache } }
                    
                    /// Complete load
                    self.completeLoad(with: stories.map { $0.response }, scoreMap: scoreMapResult.response.scoreMap, source: source)
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
                        promise(.failure(error))
                    }
                } receiveValue: { ids in
                    self.storyIds.append(contentsOf: ids.response)
                    promise(.success(ids.response))
                }
                .store(in: &self.disposeBag)
            
        }.eraseToAnyPublisher()
    }
    
    private func nextPageAvailableFromCache() -> Bool {
        if storyIds.count == 0 {
           return false
        }
        let ids = idsForPage(.page(self.currentPage + 1), with: storyIds)
        var availableInCache = true
        for id in ids {
            if !apiManager.hasCachedResponse(for: id) { availableInCache = false; break }
        }
        return availableInCache
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
    
    private func completeLoad(with stories: [Story], scoreMap: [String: HTMLAPIVote], source: APIResponseLoadSource) {
        /// Handle stories
        let viewModels = stories.map { StoryRowViewModel(story: $0) }
        self.stories.append(contentsOf: viewModels)
        
        for viewModel in viewModels {
            if SaturnKeychainWrapper.shared.isLoggedIn,
               let vote = self.availableVotes[String(viewModel.id)] {
                viewModel.vote = vote
            }
        }
        
        /// Handle scoremap (if exists)
        self.availableVotes = scoreMap
        
        for story in self.stories {
            if let vote = scoreMap[String(story.id)] {
                story.vote = vote
            }
        }
        
        /// Housekeeping after update
        self.loadingState = .loaded(source)
        self.currentPage += 1
        
        if source == .network {
            let timestamp = Date()
            SettingsManager.default.set(value: .date(timestamp), for: .lastRefreshTimestamp)
            self.lastRefreshTimestamp = timestamp
        }
    }
}

enum IDPage: Equatable {
    case current
    case page(Int)
}
