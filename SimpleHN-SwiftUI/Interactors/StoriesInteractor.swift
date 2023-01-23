//
//  StoriesInteractor.swift
//  SimpleHN-SwiftUI
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
    
    init(type: StoryListType) {
        self.type = type
    }
    
    override func didBecomeActive() {
        if case .initialLoad = loadingState {
            loadNextPage()
        }
    }
    
    func loadNextPage() {
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
        
        getStoryIds()
            .flatMap { ids -> AnyPublisher<[Story], Error> in
                /// Calculate page offsets
                let pageStart = self.currentPage * self.pageLength
                let pageEnd = min(((self.currentPage + 1) * self.pageLength), ids.count)
                let idsPage = Array(ids[pageStart..<pageEnd])
                
                /// Begin load
                return self.apiManager.loadStories(ids: idsPage)
            }
            .receive(on: RunLoop.main)
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                    self.loadingState = .failed
                }

            } receiveValue: { stories in
                if self.currentPage == 0 {
                    self.storyIds.removeAll(keepingCapacity: true)
                    self.stories.removeAll(keepingCapacity: true)
                }
                
                self.stories.append(contentsOf: stories)
                self.loadingState = .loaded
                self.currentPage += 1
            }
            .store(in: &disposeBag)
    }
    
    func getStoryIds() -> AnyPublisher<[Int], Error> {
        Future { [weak self] promise in
            guard let self else { return }
            
            if self.storyIds.isEmpty {
                self.apiManager.loadStoryIds(type: self.type)
                    .handleEvents(receiveOutput: { ids in
                        if self.storyIds.isEmpty {
                            self.storyIds.append(contentsOf: ids)
                        }
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
        Task {
            self.currentPage = 0
            loadNextPage()
        }
    }
}
