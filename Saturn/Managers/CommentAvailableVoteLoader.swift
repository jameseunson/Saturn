//
//  CommentAvailableVoteLoader.swift
//  Saturn
//
//  Created by James Eunson on 3/4/2023.
//

import Foundation
import Factory
import Combine

protocol CommentAvailableVoteLoading: AnyObject {
    func evaluateShouldLoadNextPageAvailableVotes(numberOfCommentsLoaded: Int, for story: StoryRowViewModel)
    var availableVotes: AnyPublisher<[String: HTMLAPIVote], Error> { get }
}

final class CommentAvailableVoteLoader: CommentAvailableVoteLoading {
    @Injected(\.htmlApiManager) private var htmlApiManager
    @Injected(\.keychainWrapper) private var keychainWrapper
    
    lazy var availableVotes: AnyPublisher<[String: HTMLAPIVote], Error> = availableVotesSubject.eraseToAnyPublisher()
    
    private var disposeBag = Set<AnyCancellable>()
    deinit {
        disposeBag.forEach { $0.cancel() }
    }
    
    private var hasNextPageAvailableVotes = false
    private var isLoadingNextPageAvailableVotes = false
    private var currentVotePage = 1
    
    private var availableVotesSubject = CurrentValueSubject<[String: HTMLAPIVote], Error>([:])
    
    #if DEBUG
    let isDebugLoggingEnabled = true
    #else
    let isDebugLoggingEnabled = false
    #endif
    
    /// Check if user has scrolled beyond current threshold of loaded votes from HTML API
    func evaluateShouldLoadNextPageAvailableVotes(numberOfCommentsLoaded: Int = 0, for story: StoryRowViewModel) {
        guard keychainWrapper.isLoggedIn else { return }
        
        /// Vote loading is possible when we either have:
        /// - no votes or
        /// - when we have some votes, and a server response indicating there is a subsequent page (`hasNextPageAvailableVotes`)
        let isEligibleToLoadOnSubsequentPage = !self.availableVotesSubject.value.isEmpty && hasNextPageAvailableVotes
        let isEligibleToLoadOnFirstPage = self.availableVotesSubject.value.isEmpty
        
        guard isEligibleToLoadOnFirstPage || isEligibleToLoadOnSubsequentPage else { return }
        
        if isDebugLoggingEnabled { print("CommentAvailableVoteLoader: \(numberOfCommentsLoaded) > \(self.availableVotesSubject.value.count)") }
        if numberOfCommentsLoaded >= self.availableVotesSubject.value.count,
           !isLoadingNextPageAvailableVotes {
            isLoadingNextPageAvailableVotes = true
            if isDebugLoggingEnabled {  print("CommentAvailableVoteLoader, exceeded loaded votes, page: \(currentVotePage)") }
            
            self.htmlApiManager.loadAvailableVotesForComments(page: currentVotePage, storyId: story.id)
                .sink { completion in
                    if case let .failure(error) = completion {
                        print(error)
                    }
                    // TODO:
                } receiveValue: { result in
                    var mutableVotes = self.availableVotesSubject.value
                    result.scoreMap.forEach { mutableVotes[$0] = $1 }
                    self.availableVotesSubject.send(mutableVotes)
                    
                    self.hasNextPageAvailableVotes = result.hasNextPage
                    self.currentVotePage += 1
                    self.isLoadingNextPageAvailableVotes = false
                }
                .store(in: &disposeBag)

        }
    }
}

extension CommentAvailableVoteLoading {
    func evaluateShouldLoadNextPageAvailableVotes(numberOfCommentsLoaded: Int = 0, for story: StoryRowViewModel) {
        evaluateShouldLoadNextPageAvailableVotes(numberOfCommentsLoaded: numberOfCommentsLoaded, for: story)
    }
}
