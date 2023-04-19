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
    
    var availableVoteLoader: Factory<AvailableVoteLoading> {
        self { AvailableVoteLoader() }
    }
    
    var commentLoader: Factory<CommentLoading> {
        self { CommentLoader() }
    }
    
    var commentScoreLoader: Factory<UserCommentsScoreLoading> {
        self { UserCommentsScoreLoader() }
    }
    
    var settingsManager: Factory<SettingsManaging> {
        self { SettingsManager() }
            .singleton
    }
    
    var searchApiManager: Factory<SearchAPIManaging> {
        self { SearchAPIManager() }
    }
    
    var apiMemoryResponseCache: Factory<APIMemoryResponseCaching> {
        self { APIMemoryResponseCache() }
            .singleton
    }
    
    var apiDecoder: Factory<APIDecoder> {
        self { APIDecoder() }
    }
    
    var layoutManager: Factory<LayoutManaging> {
        self { LayoutManager() }
            .singleton
    }
    
    var appRemoteConfig: Factory<AppRemoteConfig> {
        self { AppRemoteConfigImpl() }
            .singleton
    }
    
    var persistenceManager: Factory<PersistenceManager> {
        self { PersistenceManager() }
            .singleton
    }
    
    var globalErrorStream: Factory<GlobalErrorStreaming> {
        self { GlobalErrorStream() }
            .singleton
    }
    
    var favIconLoader: Factory<FavIconLoading> {
        self { FavIconLoader() }
    }
}
