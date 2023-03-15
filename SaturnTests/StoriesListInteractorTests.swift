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
        
        apiManager.loadStoryIdsHandler = { (type: StoryListType, cacheBehavior: APIMemoryResponseCacheBehavior) -> AnyPublisher<APIResponse<Array<Int>>, Error> in
            return self.publisherForStoryIds(from: [1])
        }
        
        apiManager.loadStoriesHandler = { (storyIds: [Int], cacheBehavior: APIMemoryResponseCacheBehavior) -> AnyPublisher<[APIResponse<Story>], Error> in
            return self.publisherForStories(from: [self.apiResponseForStory(with: Story.fakeStory()!)])
        }
    }
    
    func test_cachedResponseExpired_refreshAvailable() {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .minute, value: -35, to: Date())
        
        interactor = StoriesListInteractor(type: .top, apiManager: apiManager, lastRefreshTimestamp: date)
        interactor.activate()
        
        let expectation = XCTestExpectation(description: "Await cacheLoadState value")
        interactor.$cacheLoadState.dropFirst().sink { state in
            XCTAssertEqual(state, .refreshAvailable)
            expectation.fulfill()
        }
        .store(in: &disposeBag)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_cachedResponseNotExpired_refreshNotAvailable() {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .minute, value: -10, to: Date())
        
        interactor = StoriesListInteractor(type: .top, apiManager: apiManager, lastRefreshTimestamp: date)
        interactor.activate()
        
        let expectation = XCTestExpectation(description: "Await cacheLoadState value")
        interactor.$cacheLoadState.dropFirst().sink { state in
            XCTAssertEqual(state, .refreshNotAvailable)
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
        
        interactor.$canLoadNextPage.dropFirst()
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
        apiManager.hasCachedResponseHandler = { _ in return true }
        apiManager.loadStoryIdsHandler = { _, _ in return self.publisherForStoryIds(from: Array(0...20)) }
        apiManager.loadStoriesHandler = { _, _ in
            var storyResponses = [APIResponse<Story>]()
            for _ in 0...20 { storyResponses.append(self.apiResponseForStory(with: Story.fakeStory()!)) }
            
            return self.publisherForStories(from: storyResponses)
        }

        XCTAssertEqual(apiManager.hasCachedResponseCallCount, 0)
        
        let expectation = XCTestExpectation(description: "Await cacheLoadState value")
        interactor = StoriesListInteractor(type: .top, apiManager: apiManager)
        interactor.activate()
        
        interactor.$canLoadNextPage.dropFirst()
            .sink { canLoadNextPage in
                XCTAssertTrue(canLoadNextPage)
                /// Called for every story on page 2, (11-20, hence 10 calls)
                XCTAssertEqual(self.apiManager.hasCachedResponseCallCount, 10)
                expectation.fulfill()
            }
            .store(in: &disposeBag)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func test_canLoadPage_loadedFromCache_nextPageCacheDoesNotExist() {
        apiManager.hasCachedResponseHandler = { _ in return false }
        apiManager.loadStoryIdsHandler = { _, _ in return self.publisherForStoryIds(from: Array(0...20)) }
        apiManager.loadStoriesHandler = { _, _ in
            var storyResponses = [APIResponse<Story>]()
            for _ in 0...20 { storyResponses.append(self.apiResponseForStory(with: Story.fakeStory()!)) }
            
            return self.publisherForStories(from: storyResponses)
        }

        XCTAssertEqual(apiManager.hasCachedResponseCallCount, 0)
        
        let expectation = XCTestExpectation(description: "Await cacheLoadState value")
        interactor = StoriesListInteractor(type: .top, apiManager: apiManager)
        interactor.activate()
        
        interactor.$canLoadNextPage.dropFirst()
            .sink { canLoadNextPage in
                XCTAssertFalse(canLoadNextPage)
                /// First call fails, therefore subsequent calls are not evaluated, we expect only one call
                XCTAssertEqual(self.apiManager.hasCachedResponseCallCount, 1)
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
