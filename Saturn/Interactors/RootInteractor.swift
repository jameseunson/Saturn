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
        
        let numberOfLaunches = settingsManager.int(for: .numberOfLaunches)
        settingsManager.set(value: .int(numberOfLaunches + 1), for: .numberOfLaunches)
        
        if numberOfLaunches == AppRemoteConfig.instance.numberOfLaunchesToRequestReview() {
            if let windowScene = UIApplication.shared.connectedScenes.first,
               let scene = windowScene as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
    
    deinit {
        networkConnectivityManager.stop()
    }
}
