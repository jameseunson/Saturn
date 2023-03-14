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
    
    private var currentPage: Int = 0
    private var storyIds = [Int]()
    private var lastRefreshTimestamp: Date?
    
    @Published private(set) var stories = [Story]()
    @Published private(set) var loadingState: LoadingState = .initialLoad
    @Published private(set) var cacheLoadState: CacheLoadState = .refreshNotAvailable
    
    #if DEBUG
    private var displayingSwiftUIPreview = false
    #endif
    
    init(type: StoryListType,
         stories: [Story] = [],
         apiManager: APIManaging = APIManager(),
         lastRefreshTimestamp: Date? = Settings.default.date(for: .lastRefreshTimestamp)) {
        
        self.apiManager = apiManager
        self.type = type
        self.stories = stories
        self.lastRefreshTimestamp = lastRefreshTimestamp
        
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
            self.cacheLoadState = .refreshAvailable
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
                    if response.source == .cache,
                       NetworkConnectivityManager.instance.isConnected() {
                        
                        /// If last refresh was within 30 minutes, do not suggest to refresh
                        if let lastRefreshTimestamp = self.lastRefreshTimestamp,
                           let thresholdTimestamp = Calendar.current.date(byAdding: .minute, value: -30, to: Date()),
                           lastRefreshTimestamp > thresholdTimestamp {
                                self.cacheLoadState = .refreshNotAvailable
                            
                        } else {
                            /// Display the UI element prompting the user to refresh, if the response was from the offline disk cache
                            self.cacheLoadState = .refreshAvailable
                        }
                    }
                })
                .store(in: &disposeBag)
        }
    }
    
    @discardableResult
    func loadNextPage(cacheBehavior: APIMemoryResponseCacheBehavior = .default) -> AnyPublisher<APIResponse<[Story]>, Error> {
        Future { [weak self] promise in
            guard let self else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                switch self.loadingState {
                case .loadingMore:
                    return
                case .loaded, .failed:
                    self.loadingState = .loadingMore
                case .initialLoad:
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
                        promise(.failure(error))
                    }

                } receiveValue: { stories in
                    var source: APIResponseLoadSource = .network
                    stories.forEach { if $0.source == .cache { source = .cache } }
                    
                    self.completeLoad(with: stories.map { $0.response }, source: source)
                    promise(.success(APIResponse(response: stories.map { $0.response },
                                                 source: source)))
                }
                .store(in: &self.disposeBag)
        }
        .eraseToAnyPublisher()
    }
    
    func getStoryIds(cacheBehavior: APIMemoryResponseCacheBehavior = .default) -> AnyPublisher<[Int], Error> {
        Future { [weak self] promise in
            guard let self else { return }
            
            if self.storyIds.isEmpty {
                self.apiManager.loadStoryIds(type: self.type, cacheBehavior: cacheBehavior)
                    .handleEvents(receiveOutput: { ids in
                        self.storyIds.append(contentsOf: ids.response)
                    })
                    .sink { completion in
                        if case let .failure(error) = completion {
                            promise(.failure(error))
                        }
                    } receiveValue: { ids in
                        promise(.success(ids.response))
                    }
                    .store(in: &self.disposeBag)
            } else {
                promise(.success(self.storyIds))
            }
            
        }.eraseToAnyPublisher()
    }
    
    func refreshStories() async {
        do {
            self.currentPage = 0
            
            let storyIds = try await apiManager.loadStoryIds(type: self.type, cacheBehavior: .ignore)
            let stories = try await apiManager.loadStories(ids: self.idsForPage(.current, with: storyIds.response), cacheBehavior: .ignore)
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.completeLoad(with: stories.response, source: .network)
                self.cacheLoadState = .refreshNotAvailable
            }
            
        } catch {
            // TODO: Handle error
        }
    }
    
    func didTapRefreshButton() {
        cacheLoadState = .refreshing
        Task {
            await refreshStories()
        }
    }
    
    func canLoadNextPage(story: Story) -> Bool {
        guard story == stories.last,
              case let .loaded(source) = loadingState else {
            return false
        }
        switch source {
        case .network:
            return true
        case .cache:
            return nextPageAvailableFromCache()
        }
    }
    
    // MARK: -
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
        let idsPage = Array(ids[pageStart..<pageEnd])
        
        return idsPage
    }
    
    private func completeLoad(with stories: [Story], source: APIResponseLoadSource) {
        if self.currentPage == 0 {
            self.storyIds.removeAll(keepingCapacity: true)
            self.stories.removeAll(keepingCapacity: true)
        }
        
        self.stories.append(contentsOf: stories)
        self.loadingState = .loaded(source)
        self.currentPage += 1
        
        if source == .network {
            Settings.default.set(value: .date(Date()), for: .lastRefreshTimestamp)
        }
    }
}

enum CacheLoadState {
    case refreshNotAvailable
    case refreshAvailable
    case refreshing
}

enum IDPage: Equatable {
    case current
    case page(Int)
}
