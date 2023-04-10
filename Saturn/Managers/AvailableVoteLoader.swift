//
//  AvailableVoteLoader.swift
//  Saturn
//
//  Created by James Eunson on 3/4/2023.
//

import Foundation
import Factory
import Combine

protocol AvailableVoteLoading: AnyObject {
    func evaluateShouldLoadNextCommentsPageAvailableVotes(numberOfCommentsLoaded: Int, for story: StoryRowViewModel)
    func evaluateShouldLoadNextStoriesPageAvailableVotes(numberOfStoriesLoaded: Int)
    func clearVotes()
    func setType(_ voteType: VoteType)
    
    var availableVotes: AnyPublisher<[String: HTMLAPIVote], Error> { get }
}

final class AvailableVoteLoader: AvailableVoteLoading {
    @Injected(\.htmlApiManager) private var htmlApiManager
    @Injected(\.keychainWrapper) private var keychainWrapper
    @Injected(\.globalErrorStream) private var globalErrorStream
    
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
    
    func setType(_ voteType: VoteType) {
        switch voteType {
        case .stories:
            currentVotePage = 0
        case .comments(_):
            currentVotePage = 1
        }
    }
    
    /// Load next page of comment votes, if required
    /// Check if user has scrolled beyond current threshold of loaded votes from HTML API
    func evaluateShouldLoadNextCommentsPageAvailableVotes(numberOfCommentsLoaded: Int = 0, for story: StoryRowViewModel) {
        evaluate(for: .comments(story: story), numberOfItemsLoaded: numberOfCommentsLoaded)
    }
    
    /// Load next page of story votes, if required
    func evaluateShouldLoadNextStoriesPageAvailableVotes(numberOfStoriesLoaded: Int = 0) {
        evaluate(for: .stories, numberOfItemsLoaded: numberOfStoriesLoaded)
    }
    
    func clearVotes() {
        availableVotesSubject.send([:])
    }
    
    // MARK: - Private
    private func evaluate(for voteType: VoteType, numberOfItemsLoaded: Int) {
        guard isEligibleToLoad() else { return }
        
        if isDebugLoggingEnabled { print("AvailableVoteLoader, \(voteType): \(numberOfItemsLoaded) > \(self.availableVotesSubject.value.count)") }
        guard numberOfItemsLoaded >= self.availableVotesSubject.value.count,
              !isLoadingNextPageAvailableVotes else { return }
        
        isLoadingNextPageAvailableVotes = true
        if isDebugLoggingEnabled {  print("AvailableVoteLoader, \(voteType), exceeded loaded votes, page: \(currentVotePage)") }
        
        stream(for: voteType)
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                    self.globalErrorStream.addError(error)
                }
            } receiveValue: { response in
                let result = response.response
                
                var mutableVotes = self.availableVotesSubject.value
                result.scoreMap.forEach { mutableVotes[$0] = $1 }
                self.availableVotesSubject.send(mutableVotes)
                
                self.hasNextPageAvailableVotes = result.hasNextPage
                self.currentVotePage += 1
                self.isLoadingNextPageAvailableVotes = false
            }
            .store(in: &disposeBag)
    }
    
    private func stream(for voteType: VoteType) -> AnyPublisher<APIResponse<VoteHTMLParserResponse>, Error> {
        switch voteType {
        case .stories:
            return self.htmlApiManager.loadAvailableVotesForStoriesList(page: currentVotePage)
        case .comments(let story):
            return self.htmlApiManager.loadAvailableVotesForComments(page: currentVotePage, storyId: story.id)
        }
    }
    
    private func isEligibleToLoad() -> Bool {
        guard keychainWrapper.isLoggedIn else { return false }
        
        /// Vote loading is possible when we either have:
        /// - no votes or
        /// - when we have some votes, and a server response indicating there is a subsequent page (`hasNextPageAvailableVotes`)
        let isEligibleToLoadOnSubsequentPage = !self.availableVotesSubject.value.isEmpty && hasNextPageAvailableVotes
        let isEligibleToLoadOnFirstPage = self.availableVotesSubject.value.isEmpty
        
        guard isEligibleToLoadOnFirstPage || isEligibleToLoadOnSubsequentPage else { return false }
        
        return true
    }
}

extension AvailableVoteLoading {
    func evaluateShouldLoadNextCommentsPageAvailableVotes(numberOfCommentsLoaded: Int = 0, for story: StoryRowViewModel) {
        evaluateShouldLoadNextCommentsPageAvailableVotes(numberOfCommentsLoaded: numberOfCommentsLoaded, for: story)
    }
    func evaluateShouldLoadNextStoriesPageAvailableVotes(numberOfStoriesLoaded: Int = 0) {
        evaluateShouldLoadNextStoriesPageAvailableVotes(numberOfStoriesLoaded: numberOfStoriesLoaded)
    }
}

enum VoteType {
    case stories
    case comments(story: StoryRowViewModel)
    
    var description: String {
        switch self {
        case .stories:
            return "Stories"
        case .comments(_):
            return "Comments"
        }
    }
}