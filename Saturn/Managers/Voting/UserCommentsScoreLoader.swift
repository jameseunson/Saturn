//
//  UserCommentsScoreLoader.swift
//  Saturn
//
//  Created by James Eunson on 13/4/2023.
//

import Foundation
import Factory
import Combine

protocol UserCommentsScoreLoading: AnyObject {
    func evaluateShouldLoadScoresForLoggedInUserComments(numberOfCommentsLoaded: Int)
    func clearScores()
    var scoreMap: AnyPublisher<ScoreMap, Error> { get }
}

final class UserCommentsScoreLoader: UserCommentsScoreLoading {
    @Injected(\.htmlApiManager) private var htmlApiManager
    @Injected(\.keychainWrapper) private var keychainWrapper
    @Injected(\.globalErrorStream) private var globalErrorStream
    
    private var disposeBag = Set<AnyCancellable>()
    deinit {
        disposeBag.forEach { $0.cancel() }
    }
    
    lazy var scoreMap: AnyPublisher<ScoreMap, Error> = scoreMapSubject.eraseToAnyPublisher()
    private var scoreMapSubject = CurrentValueSubject<ScoreMap, Error>([:])
    
    private var isLoadingNextPageScoreMap = false
    private var nextPageItemId: Int?
    
    func evaluateShouldLoadScoresForLoggedInUserComments(numberOfCommentsLoaded: Int = 0) {
        guard isEligibleToLoad(),
            !isLoadingNextPageScoreMap else { return }
        
        print("UserCommentsScoreLoader: \(numberOfCommentsLoaded) > \(self.scoreMapSubject.value.count)")
        guard numberOfCommentsLoaded >= self.scoreMapSubject.value.count,
              !isLoadingNextPageScoreMap else { return }
        
        self.isLoadingNextPageScoreMap = true
        print("UserCommentsScoreLoader, exceeded loaded votes, loading: \(String(describing: nextPageItemId))")
        
        self.htmlApiManager.loadScoresForLoggedInUserComments(startFrom: nextPageItemId)
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                    self.globalErrorStream.addError(error)
                }
            } receiveValue: { response in
                let result = response.response
                
                var mutableScoreMap = self.scoreMapSubject.value
                result.scoreMap.forEach { mutableScoreMap[$0] = $1 }
                self.scoreMapSubject.send(mutableScoreMap)
                
                self.nextPageItemId = result.nextPageItemId
                print("UserCommentsScoreLoader, loaded new votes, next page: \(String(describing: result.nextPageItemId))")
                
                self.isLoadingNextPageScoreMap = false
            }
            .store(in: &disposeBag)
    }
    
    func clearScores() {
        scoreMapSubject.send([:])
        nextPageItemId = nil
    }
    
    // MARK: -
    private func isEligibleToLoad() -> Bool {
        guard keychainWrapper.isLoggedIn else { return false }
        
        /// Vote loading is possible when we either have:
        /// - no votes or
        /// - when we have some votes, and a server response indicating there is a subsequent page (`hasNextPageAvailableVotes`)
        let isEligibleToLoadOnSubsequentPage = !self.scoreMapSubject.value.isEmpty && nextPageItemId != nil
        let isEligibleToLoadOnFirstPage = self.scoreMapSubject.value.isEmpty
        
        guard isEligibleToLoadOnFirstPage || isEligibleToLoadOnSubsequentPage else { return false }
        
        return true
    }
}

extension UserCommentsScoreLoading {
    func evaluateShouldLoadScoresForLoggedInUserComments(numberOfCommentsLoaded: Int = 0) {
        evaluateShouldLoadScoresForLoggedInUserComments(numberOfCommentsLoaded: numberOfCommentsLoaded)
    }
}
