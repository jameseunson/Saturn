//
//  StoriesInteractor.swift
//  Saturn
//
//  Created by James Eunson on 8/1/2023.
//

import Combine
import Foundation
import SwiftUI

final class StoriesInteractor: Interactor {
    @Published var canLoadMore: Bool = true
    
    let apiManager = APIManager()
    let pageLength = 10
    let type: StoryListType
    
    var currentPage: Int = 0
    var storyIds = [Int]()
    @Published var stories = [Story]()
    @Published var loadingState: LoadingState = .initialLoad
    @Published var cacheLoadState: CacheLoadState = .refreshNotAvailable
    
    #if DEBUG
    private var displayingSwiftUIPreview = false
    #endif
    
    init(type: StoryListType, stories: [Story] = []) {
        self.type = type
        self.stories = stories
        
        #if DEBUG
        if stories.count > 0 {
            self.displayingSwiftUIPreview = true
        }
        #endif
    }
    
    override func didBecomeActive() {
        #if DEBUG
        if displayingSwiftUIPreview {
            self.loadingState = .loaded
            self.cacheLoadState = .refreshAvailable
            return
        }
        #endif
        
        if case .initialLoad = loadingState {
            loadNextPage(cacheBehavior: .offlineOnly)
                .sink(receiveCompletion: { _ in }, receiveValue: { response in
                    if response.source == .cache,
                       NetworkConnectivityManager.instance.isConnected() {
                        self.cacheLoadState = .refreshAvailable
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
                    return self.apiManager.loadStories(ids: self.idsForCurrentPage(with: ids), cacheBehavior: cacheBehavior)
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
                    
                    self.completeLoad(with: stories.map { $0.response })
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
            let stories = try await apiManager.loadStories(ids: self.idsForCurrentPage(with: storyIds.response), cacheBehavior: .ignore)
            
            DispatchQueue.main.async { [weak self] in
                self?.completeLoad(with: stories.response)
            }
            self.cacheLoadState = .refreshNotAvailable
            
        } catch {
            // TODO: Handle error
        }
    }
    
    // MARK: -
    
    /// Calculate page offsets
    private func idsForCurrentPage(with ids: [Int]) -> [Int] {
        let pageStart = self.currentPage * self.pageLength
        let pageEnd = min(((self.currentPage + 1) * self.pageLength), ids.count)
        let idsPage = Array(ids[pageStart..<pageEnd])
        
        return idsPage
    }
    
    private func completeLoad(with stories: [Story]) {
        if self.currentPage == 0 {
            self.storyIds.removeAll(keepingCapacity: true)
            self.stories.removeAll(keepingCapacity: true)
        }
        
        self.stories.append(contentsOf: stories)
        self.loadingState = .loaded
        self.currentPage += 1
    }
}

enum CacheLoadState {
    case refreshNotAvailable
    case refreshAvailable
    case refreshing
}
