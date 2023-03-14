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
            return Just(APIResponse<Array<Int>>.init(response: [1], source: .cache)).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        
        apiManager.loadStoriesHandler = { (storyIds: [Int], cacheBehavior: APIMemoryResponseCacheBehavior) -> AnyPublisher<[APIResponse<Story>], Error> in
            return Just([APIResponse<Story>(response: Story.fakeStory()!, source: .cache)]).setFailureType(to: Error.self).eraseToAnyPublisher()
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
}
