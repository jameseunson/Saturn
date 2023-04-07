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
    var apiManager: Factory<APIManaging> {
        self { APIManager() }
    }
    var htmlApiManager: Factory<HTMLAPIManaging> {
        self { HTMLAPIManager() }
    }
    var voteManager: Factory<VoteManaging> {
        self { VoteManager() }
    }
    var commentAvailableVoteLoader: Factory<CommentAvailableVoteLoading> {
        self { CommentAvailableVoteLoader() }
    }
    var commentLoader: Factory<CommentLoading> {
        self { CommentLoader() }
    }
}
