//
//  RootInteractor.swift
//  Saturn
//
//  Created by James Eunson on 19/1/2023.
//

import Foundation

final class RootInteractor: Interactor {
    override func didBecomeActive() {
        NetworkConnectivityManager.instance.start()
    }
    
    deinit {
        NetworkConnectivityManager.instance.stop()
    }
}
