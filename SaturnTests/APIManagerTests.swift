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
    let ref = DatabaseReferenceMock()
    
    var disposeBag = Set<AnyCancellable>()
    deinit {
        disposeBag.forEach { $0.cancel() }
    }
    
    func test_retrieveObject_valueNotExpired_used() {
        let cache = APIMemoryResponseCacheMock(timestamp: Date())
        
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
        
        XCTAssert(cache.getCalled)
        XCTAssertFalse(cache.setCalled)
    }
    
    func test_retrieveObject_valueExpired_notUsed() {
        let cache = APIMemoryResponseCacheMock(timestamp: Date().addingTimeInterval(-(60*11)))
        
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
        
        XCTAssert(cache.getCalled)
        XCTAssert(cache.setCalled) /// Set operation on the cache indicates a network request was successful
    }
}

final class APIMemoryResponseCacheMock: APIMemoryResponseCaching {
    var setCalled = false
    var getCalled = false
    
    let timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
    
    func set(value: Any, for key: Int) {
        setCalled = true
    }
    
    func get(for key: Int) -> APIMemoryResponseCacheItem? {
        getCalled = true
        
        return APIMemoryResponseCacheItem(value: Story.fakeStoryDict(),
                                          timestamp: timestamp)
    }
}

final class DataSnapshotMock: DataShapshotting {
    let value: Any?
    
    init(value: Any) {
        self.value = value
    }
}

final class DatabaseReferenceMock: DatabaseReferencing {
    var childPathCalled = false
    var getChildDataCalled = false
    
    func childPath(_ pathString: String) -> Saturn.DatabaseReferencing {
        childPathCalled = true
        return DatabaseReferenceMock()
    }
    
    func getChildData(completion block: @escaping (Error?, Saturn.DataShapshotting?) -> Void) {
        getChildDataCalled = true
        block(nil, DataSnapshotMock(value: Story.fakeStoryDict()))
    }
}
