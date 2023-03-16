//
//  RootInteractorTests.swift
//  SaturnTests
//
//  Created by James Eunson on 16/3/2023.
//

import Foundation
@testable import Saturn
import XCTest
import Firebase
import FirebaseCore

final class RootInteractorTests: XCTestCase {
    var interactor: RootInteractor!
    let settingsManager = SettingsManagingMock()
    
    override func setUp() {
        super.setUp()
        
        interactor = RootInteractor(settingsManager: settingsManager)
    }
    
    func test_didBecomeActive_incrementsNumberOfLaunches() {
        settingsManager.intHandler = { key in
            return 0
        }
        settingsManager.setHandler = { value, key in
            XCTAssertEqual(key, .numberOfLaunches)
            XCTAssertEqual(value, .int(1))
        }
        
        XCTAssertEqual(settingsManager.setCallCount, 0)
        XCTAssertEqual(settingsManager.intCallCount, 0)
        
        interactor.didBecomeActive()
        
        XCTAssertEqual(settingsManager.setCallCount, 1)
        XCTAssertEqual(settingsManager.intCallCount, 1)
    }
}
