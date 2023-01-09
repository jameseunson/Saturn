//
//  TopStoriesViewModel.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 8/1/2023.
//

import Combine
import Foundation
import SwiftUI

final class TopStoriesViewModel: ViewModel {
    @Published var canLoadMore: Bool = true
    
    let apiManager = APIManager()
    let pageLength = 10
    
    var currentPage: Int = 0
    var storyIds = [Int]()
    @Published var stories = [Story]()
    @Published var loadingState: LoadingState = .initialLoad
    
    override func didBecomeActive() {
        if case .initialLoad = loadingState {
            loadNextPage()
        }
    }
    
    func loadNextPage() {
        switch loadingState {
        case .loadingMore:
            return
        case .loaded, .failed:
            loadingState = .loadingMore
        default:
            break
        }
        
        apiManager.loadTopStoryIds()
            .handleEvents(receiveOutput: { ids in
                self.storyIds.append(contentsOf: ids)
            })
            .flatMap { ids -> AnyPublisher<[Story], Error> in
                /// Calculate page offsets
                let pageStart = self.currentPage * self.pageLength
                let pageEnd = ((self.currentPage + 1) * self.pageLength)
                let idsPage = Array(ids[pageStart..<pageEnd])
                
                /// Begin load
                return self.apiManager.loadTopStories(ids: idsPage)
            }
            .receive(on: RunLoop.main)
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                    self.loadingState = .failed
                }

            } receiveValue: { stories in
                self.stories.append(contentsOf: stories)
                self.loadingState = .loaded
                self.currentPage += 1
            }
            .store(in: &disposeBag)
    }
    
    func refreshStories() {
        
    }
}
