//
//  RootInteractor.swift
//  Saturn
//
//  Created by James Eunson on 19/1/2023.
//

import Foundation
import UIKit
import StoreKit

final class RootInteractor: Interactor {
    let settingsManager: SettingsManaging
    let networkConnectivityManager: NetworkConnectivityManaging
    
    init(settingsManager: SettingsManaging = SettingsManager.default,
         networkConnectivityManager: NetworkConnectivityManaging = NetworkConnectivityManager.instance) {
        self.settingsManager = settingsManager
        self.networkConnectivityManager = networkConnectivityManager
    }
    
    override func didBecomeActive() {
        networkConnectivityManager.start()
        
        /// Don't continue to increment launch counter if user has already seen review prompt
        let hasSeenReviewPrompt = settingsManager.bool(for: .hasSeenReviewPrompt)
        if hasSeenReviewPrompt {
            return
        }
        
        /// Increment launch counter by one for each launch until we hit the threshold to
        /// show the review prompt, which is 3 by default
        let numberOfLaunches = settingsManager.int(for: .numberOfLaunches)
        settingsManager.set(value: .int(numberOfLaunches + 1), for: .numberOfLaunches)
        
        if numberOfLaunches == AppRemoteConfig.instance.numberOfLaunchesToRequestReview() {
            if let windowScene = UIApplication.shared.connectedScenes.first,
               let scene = windowScene as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
                settingsManager.set(value: .bool(true), for: .hasSeenReviewPrompt)
            }
        }
    }
    
    deinit {
        networkConnectivityManager.stop()
    }
}
