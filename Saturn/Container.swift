//
//  Container.swift
//  Saturn
//
//  Created by James Eunson on 27/3/2023.
//

import Foundation
import Factory

extension Container {
    var networkConnectivityManager: Factory<NetworkConnectivityManaging> {
        self { NetworkConnectivityManager() }
            .singleton
    }
    var keychainWrapper: Factory<SaturnKeychainWrapping> {
        self { SaturnKeychainWrapper() }
            .singleton
    }
}
