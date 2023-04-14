//
//  RootInteractor.swift
//  Saturn
//
//  Created by James Eunson on 19/1/2023.
//

import Foundation
import UIKit
import StoreKit
import Factory

final class RootInteractor: Interactor {
    @Injected(\.settingsManager) private var settingsManager
    @Injected(\.networkConnectivityManager) private var networkConnectivityManager
    @Injected(\.appRemoteConfig) private var appRemoteConfig

    override func didBecomeActive() {
        print(FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask))
        
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
        
        if appRemoteConfig.isAutoPromptForReviewEnabled(),
           numberOfLaunches >= appRemoteConfig.numberOfLaunchesToRequestReview() {
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
