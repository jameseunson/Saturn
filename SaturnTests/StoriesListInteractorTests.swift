//
//  StoriesListInteractorTests.swift
//  SaturnTests
//
//  Created by James Eunson on 8/3/2023.
//

import Foundation
import XCTest
@testable import Saturn
import Combine

final class StoriesListInteractorTests: XCTestCase {
    let apiManager = APIManagingMock()
    var interactor: StoriesListInteractor!
    
    var disposeBag = Set<AnyCancellable>()
    deinit {
        disposeBag.forEach { $0.cancel() }
    }
    
    override func setUp() {
        super.setUp()
        
        apiManager.loadStoryIdsHandler = { (type: StoryListType, cacheBehavior: CacheBehavior) -> AnyPublisher<APIResponse<Array<Int>>, Error> in
            return self.publisherForStoryIds(from: [1])
        }
        
        apiManager.loadStoriesHandler = { (storyIds: [Int], cacheBehavior: CacheBehavior) -> AnyPublisher<[APIResponse<Story>], Error> in
            return self.publisherForStories(from: [self.apiResponseForStory(with: Story.fakeStory()!)])
        }
    }
    
    func test_cachedResponseExpired_refreshesImmediately() {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .minute, value: -15, to: Date())
        
        interactor = StoriesListInteractor(type: .top, apiManager: apiManager, lastRefreshTimestamp: date)
        interactor.activate()
        
        let expectation = XCTestExpectation(description: "Await loadState value")
        interactor.$loadingState.sink { state in
            if state == .refreshing {
                expectation.fulfill()
            }
        }
        .store(in: &disposeBag)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_cachedResponseNotExpired_doNotRefresh() {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .minute, value: -5, to: Date())
        
        interactor = StoriesListInteractor(type: .top, apiManager: apiManager, lastRefreshTimestamp: date)
        interactor.activate()
        
        let expectation = XCTestExpectation(description: "Await loadState value")
        interactor.$loadingState.dropFirst().sink { state in
            XCTAssertEqual(state, .loaded(.cache))
            expectation.fulfill()
        }
        .store(in: &disposeBag)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_canLoadPage_loadedFromNetwork() {
        apiManager.hasCachedResponseHandler = { _ in return false }
        apiManager.loadStoryIdsHandler = { _, _ in return self.publisherForStoryIds(from: Array(0...20), source: .network) }
        apiManager.loadStoriesHandler = { _, _ in
            var storyResponses = [APIResponse<Story>]()
            for _ in 0...20 { storyResponses.append(self.apiResponseForStory(with: Story.fakeStory()!, source: .network)) }
            
            return self.publisherForStories(from: storyResponses)
        }

        XCTAssertEqual(apiManager.hasCachedResponseCallCount, 0)
        
        let expectation = XCTestExpectation(description: "Await cacheLoadState value")
        interactor = StoriesListInteractor(type: .top, apiManager: apiManager)
        interactor.activate()
        
        interactor.$canLoadNextPage
            .sink { canLoadNextPage in
                XCTAssertTrue(canLoadNextPage)
                /// Never called because we're pulling from the network
                XCTAssertEqual(self.apiManager.hasCachedResponseCallCount, 0)
                expectation.fulfill()
            }
            .store(in: &disposeBag)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_canLoadPage_loadedFromCache_nextPageCacheExists() {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .minute, value: -5, to: Date())
        
        apiManager.hasCachedResponseHandler = { _ in return true }
        apiManager.loadStoryIdsHandler = { _, _ in return self.publisherForStoryIds(from: Array(0...20)) }
        apiManager.loadStoriesHandler = { _, _ in
            var storyResponses = [APIResponse<Story>]()
            for _ in 0...20 { storyResponses.append(self.apiResponseForStory(with: Story.fakeStory()!)) }
            
            return self.publisherForStories(from: storyResponses)
        }

        XCTAssertEqual(apiManager.hasCachedResponseCallCount, 0)
        
        let expectation = XCTestExpectation(description: "Await cacheLoadState value")
        interactor = StoriesListInteractor(type: .top, apiManager: apiManager, lastRefreshTimestamp: date)
        interactor.activate()
        
        interactor.$canLoadNextPage.dropFirst()
            .sink { canLoadNextPage in
                XCTAssertTrue(canLoadNextPage)
                /// Called for 2 pages worth of content, 20 calls
                XCTAssertEqual(self.apiManager.hasCachedResponseCallCount, 20)
                expectation.fulfill()
            }
            .store(in: &disposeBag)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_canLoadPage_loadedFromCache_nextPageCacheDoesNotExist() {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .minute, value: -5, to: Date())
        
        apiManager.hasCachedResponseHandler = { _ in return false }
        apiManager.loadStoryIdsHandler = { _, _ in return self.publisherForStoryIds(from: Array(0...20)) }
        apiManager.loadStoriesHandler = { _, _ in
            var storyResponses = [APIResponse<Story>]()
            for _ in 0...20 { storyResponses.append(self.apiResponseForStory(with: Story.fakeStory()!)) }
            
            return self.publisherForStories(from: storyResponses)
        }

        XCTAssertEqual(apiManager.hasCachedResponseCallCount, 0)
        
        let expectation = XCTestExpectation(description: "Await cacheLoadState value")
        interactor = StoriesListInteractor(type: .top, apiManager: apiManager, lastRefreshTimestamp: date)
        interactor.activate()
        
        interactor.$canLoadNextPage.dropFirst()
            .sink { canLoadNextPage in
                XCTAssertFalse(canLoadNextPage)
                /// First call fails for both pages, 2 calls
                XCTAssertEqual(self.apiManager.hasCachedResponseCallCount, 2)
                expectation.fulfill()
            }
            .store(in: &disposeBag)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: -
    func publisherForStoryIds(from array: Array<Int>, source: APIResponseLoadSource = .cache) -> AnyPublisher<APIResponse<Array<Int>>, Error> {
        return Just(APIResponse<Array<Int>>(response: array, source: source))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func publisherForStories(from array: [APIResponse<Story>]) -> AnyPublisher<[APIResponse<Story>], Error> {
        return Just(array)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    func apiResponseForStory(with story: Story, source: APIResponseLoadSource = .cache) -> APIResponse<Story> {
        return APIResponse<Story>(response: Story.fakeStory()!, source: source)
    }
}
