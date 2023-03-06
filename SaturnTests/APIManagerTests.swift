//
//  APIManagerTests.swift
//  SaturnTests
//
//  Created by James Eunson on 16/2/2023.
//

import Foundation
import XCTest
@testable import Saturn
import Combine

final class APIManagerTests: XCTestCase {
    var apiManager: APIManager!
    let ref = DatabaseReferencingMock()
    
    var disposeBag = Set<AnyCancellable>()
    deinit {
        disposeBag.forEach { $0.cancel() }
    }
    
    override func setUp() {
        super.setUp()
        
        ref.childPathHandler = { [weak self] _ in
            guard let self else {
                XCTFail()
                return DatabaseReferencingMock()
            }
            return self.ref
        }
        ref.getChildDataHandler = { block in
            return block(nil, DataShapshottingMock(value: Story.fakeStoryDict()))
        }
    }
    
    func test_retrieveObject_valueNotExpired_used() {
        let cache = APIMemoryResponseCachingMock()
        cache.getHandler = { _ in
            return APIMemoryResponseCacheItem(value: Story.fakeStoryDict(),
                                              timestamp: Date())
        }
        
        apiManager = APIManager(cache: cache, ref: ref)
        let expectation = XCTestExpectation(description: "Await apiManager response")
        
        var receivedStory: Bool = false
        apiManager.loadStory(id: 1234)
            .sink { _ in }
            receiveValue: { story in
                receivedStory = true
                expectation.fulfill()
            }
            .store(in: &disposeBag)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssert(receivedStory)
        
        XCTAssertEqual(cache.getCallCount, 1)
        XCTAssertEqual(cache.setCallCount, 0)
    }
    
    func test_retrieveObject_valueExpired_notUsed() {
        let cache = APIMemoryResponseCachingMock()
        cache.getHandler = { _ in
            return APIMemoryResponseCacheItem(value: Story.fakeStoryDict(),
                                              timestamp: Date().addingTimeInterval(-(60*11)))
        }
    
        apiManager = APIManager(cache: cache, ref: ref)
        let expectation = XCTestExpectation(description: "Await apiManager response")
        
        var receivedStory: Bool = false
        apiManager.loadStory(id: 1234)
            .sink { _ in }
            receiveValue: { story in
                receivedStory = true
                expectation.fulfill()
            }
            .store(in: &disposeBag)
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssert(receivedStory)
        
        XCTAssertEqual(cache.getCallCount, 1)
        XCTAssertEqual(cache.setCallCount, 1) /// Set operation on the cache indicates a network request was successful
    }
}
