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
    @Published var favIcons = [Story: Image]()
    
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
            return
        }
        #endif
        
        if case .initialLoad = loadingState {
            loadNextPage(cacheBehavior: .offlineOnly)
                .flatMap { _ in
                    if NetworkConnectivityManager.instance.isConnected {
                        return self.loadNextPage()
                    } else {
                        return Empty<[Story], Error>().eraseToAnyPublisher()
                    }
                }
                .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
                .store(in: &disposeBag)
        }
        
        $stories
            .flatMap { (stories: [Story]) in
                let publishers = stories.map { story in
                    if let image = self.favIcons[story] {
                        return Just((image, story))
                            .eraseToAnyPublisher()
                    } else {
                        return self.apiManager.loadImage(for: story)
                            .map { ($0, story) }
                            .eraseToAnyPublisher()
                    }
                }
                return Publishers.MergeMany(publishers)
                    .eraseToAnyPublisher()
            }
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    print(error)
                }
            }, receiveValue: { output in
                let (image, story) = output
                self.favIcons[story] = image
            })
            .store(in: &disposeBag)
    }
    
    @discardableResult
    func loadNextPage(cacheBehavior: APIMemoryResponseCacheBehavior = .default) -> AnyPublisher<[Story], Error> {
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
            
            self.getStoryIds()
                .flatMap { ids -> AnyPublisher<[Story], Error> in
                    return self.apiManager.loadStories(ids: self.idsForCurrentPage(with: ids))
                }
                .receive(on: RunLoop.main)
                .sink { completion in
                    if case let .failure(error) = completion {
                        print(error)
                        self.loadingState = .failed
                        promise(.failure(error))
                    }

                } receiveValue: { stories in
                    self.completeLoad(with: stories)
                    promise(.success(stories))
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
                        self.storyIds.append(contentsOf: ids)
                    })
                    .sink { completion in
                        if case let .failure(error) = completion {
                            promise(.failure(error))
                        }
                    } receiveValue: { ids in
                        promise(.success(ids))
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
            let stories = try await apiManager.loadStories(ids: self.idsForCurrentPage(with: storyIds), cacheBehavior: .ignore)
            
            DispatchQueue.main.async { [weak self] in
                self?.completeLoad(with: stories)
            }
            
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
