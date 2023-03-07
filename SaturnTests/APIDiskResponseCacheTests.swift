//
//  APIDiskResponseCacheTests.swift
//  SaturnTests
//
//  Created by James Eunson on 16/2/2023.
//

import Foundation
import XCTest
@testable import Saturn
import Combine

final class APIDiskResponseCacheTests: XCTestCase {
    var cache: APIDiskResponseCache!
    let fm = FileManagingMock()
    
    override func setUp() {
        super.setUp()
        
        cache = APIDiskResponseCache(fileManager: fm)
        
        fm.urlsHandler = { _, _ in
            return [URL(filePath: "/")]
        }
        fm.fileExistsHandler = { _ in
            return true
        }
        fm.contentsOfDirectoryHandler = { _, _, _ in
            return [URL(filePath: "/HNCache/1234")]
        }
        fm.contentsHandler = { _ in
            return Data()
        }
        fm.attributesOfItemHandler = { _ in
            return [:]
        }
    }
    
    func test_loadAll_expiredResponse_isDeleted() {
        fm.attributesOfItemHandler = { _ in
            let calendar = Calendar.current
            guard let date = calendar.date(byAdding: .day, value: -14, to: Date()) else {
                XCTFail()
                return [:]
            }
            
            return [.creationDate: date]
        }
        fm.removeItemHandler = { path in
            XCTAssertEqual(path, "/HNCache/1234")
        }
        
        XCTAssertEqual(fm.removeItemCallCount, 0)
        _ = cache.loadAll()
        
        XCTAssertEqual(fm.removeItemCallCount, 1)
    }
    
    func test_loadAll_unexpiredResponse_isNotDeleted() {
        fm.attributesOfItemHandler = { _ in
            let calendar = Calendar.current
            guard let date = calendar.date(byAdding: .day, value: -6, to: Date()) else {
                XCTFail()
                return [:]
            }
            
            return [.creationDate: date]
        }
        
        XCTAssertEqual(fm.removeItemCallCount, 0)
        _ = cache.loadAll()
        
        XCTAssertEqual(fm.removeItemCallCount, 0)
    }
}
