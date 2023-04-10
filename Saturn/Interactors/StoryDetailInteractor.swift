//
//  StoryDetailInteractor.swift
//  Saturn
//
//  Created by James Eunson on 9/1/2023.
//

import Combine
import Foundation
import SwiftUI
import UIKit
import Factory

final class StoryDetailInteractor: Interactor, InfiniteScrollViewLoading {
    // MARK: - Deps
    @Injected(\.apiManager) private var apiManager
    @Injected(\.htmlApiManager) private var htmlApiManager
    @Injected(\.voteManager) private var voteManager
    @Injected(\.availableVoteLoader) private var availableVoteLoader
    @Injected(\.keychainWrapper) private var keychainWrapper
    @Injected(\.commentLoader) private var commentLoader
    @Injected(\.globalErrorStream) private var globalErrorStream
    
    // MARK: - Public
    @Published private(set) var readyToLoadMore: Bool = false
    @Published private(set) var commentsRemainingToLoad: Bool = true
    @Published private(set) var story: StoryRowViewModel?
    @Published private(set) var availableVotes: [String: HTMLAPIVote] = [:]
    
    @Published private(set) var focusedCommentViewModel: CommentViewModel?
    @Published private(set) var hasPendingExpandedUpdate: Bool = false /// Bypass debounce for comment expand/collapse
    
    var commentsDebounced: AnyPublisher<Array<CommentViewModel>, Never> = Empty().eraseToAnyPublisher()
    var commentsExpanded = CurrentValueSubject<Dictionary<CommentViewModel, CommentExpandedState>, Never>([:])
    var commentsExpandedDebounced: AnyPublisher<Dictionary<CommentViewModel, CommentExpandedState>, Never> = Empty().eraseToAnyPublisher()
    
    // MARK: - Private
    private var comments = CurrentValueSubject<Array<CommentViewModel>, Never>([])
    private var commentsLoaded = CurrentValueSubject<Int, Never>(0)
    private var currentlyLoadingComment = CurrentValueSubject<CommentViewModel?, Never>(nil)
    
    private var itemId: Int?
    private var topLevelComments = [CommentViewModel]()
    private var loadedTopLevelComments = [Int]()
    
    // MARK: - Comment Focused View
    private var commentChain = [Comment]()
    
    #if DEBUG
    private var displayingSwiftUIPreview = false
    #endif
    
    /// Entry from StoriesView, we already have a `Story` object
    init(story: StoryRowViewModel, comments: [CommentViewModel] = []) {
        self.itemId = story.id
        self.story = story
        
        #if DEBUG
        if comments.count > 0 {
            self.comments.send(comments)
            self.commentsLoaded.send(comments.count)
            self.topLevelComments = comments
            self.displayingSwiftUIPreview = true
            self.commentsRemainingToLoad = false
        }
        #endif
    }
    
    /// Entry from search results or intercepting internal links like news.ycombinator.com/item?id=1234
    /// where we don't yet have a full `Story` or `Comment` object, and it must be loaded as part of the interactor startup
    init(itemId: Int) {
        self.itemId = itemId
    }
    
    init(comment: CommentViewModel, thread: CommentLoaderContainer) {
        if let story = thread.story {
            self.story = StoryRowViewModel(story: story)
            self.commentChain = [comment.comment]
            self.commentChain.insert(contentsOf: thread.commentChain, at: 0)
            
            super.init()
            
            self.processComments()
            
        } else {
            self.itemId = comment.id
            super.init()
        }
    }
    
    override func didBecomeActive() {
        commentsDebounced = comments.debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
        commentsExpandedDebounced = commentsExpanded.debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
        
        #if DEBUG
        if displayingSwiftUIPreview { return }
        #endif
        
        /// Workaround for the fact that we have no idea when loading is complete
        /// and the backend always returns fewer comments than is indicated by
        /// `descendants` on the Story model
        commentsLoaded
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { _ in
                self.comments.send(self.flatten())
        }
        .store(in: &disposeBag)
        
        currentlyLoadingComment
            .compactMap { $0 }
            .flatMap { comment in
                if comment.comment.kids != nil {
                    return self.commentsLoaded
                        .debounce(for: .seconds(1), scheduler: RunLoop.main)
                        .map { _ in () }
                        .eraseToAnyPublisher()
                } else {
                    return Just(())
                        .eraseToAnyPublisher()
                }
            }
            .receive(on: RunLoop.main)
            .sink { _ in
                self.currentlyLoadingComment.send(nil)
                self.readyToLoadMore = true
            }
            .store(in: &disposeBag)
        
        if let itemId {
            apiManager.loadUserItem(id: itemId)
                .receive(on: RunLoop.main)
                .sink { completion in
                    if case let .failure(error) = completion {
                        self.globalErrorStream.addError(error)
                        print(error)
                    }
                } receiveValue: { item in
                    switch item {
                    case let .story(story):
                        let storyModel = StoryRowViewModel(story: story, vote: self.story?.vote)
                        self.story = storyModel
                        self.loadComments()
                        
                    case let .comment(comment):
                        self.commentChain = [comment]
                        self.traverse(comment)
                    }
                }
                .store(in: &disposeBag)
            
        } else if commentChain.isEmpty {
            loadComments()
        }
        
        /// Load voting information about each comment, if the user is logged in (as the user can only vote
        /// if they are logged in)
        if keychainWrapper.isLoggedIn {
            availableVoteLoader.availableVotes
                .receive(on: RunLoop.main)
                .sink { completion in
                    if case let .failure(error) = completion {
                        self.globalErrorStream.addError(error)
                        print(error)
                    }
                } receiveValue: { scoreMap in
                    self.availableVotes = scoreMap

                    for comment in self.comments.value {
                        if let vote = scoreMap[String(comment.id)] {
                            comment.vote = vote
                        }
                    }
                    self.objectWillChange.send()
                }
                .store(in: &disposeBag)
            
            Publishers.CombineLatest($story.compactMap { $0 },
                                     commentsDebounced.filter { !$0.isEmpty }.prefix(1)) /// Ensure only loads once comments are at least partially loaded, avoiding redundant requests
                .sink { story, _ in
                    self.availableVoteLoader.setType(.comments(story: story))
                    self.availableVoteLoader.evaluateShouldLoadNextCommentsPageAvailableVotes(for: story)
                }
                .store(in: &disposeBag)
        }
    }
    
    func loadComments() {
        guard let kids = story?.story.kids,
              let firstKid = kids.first else {
            return
        }
        
        traverse(firstKid)
        loadedTopLevelComments.append(firstKid)
        
        if loadedTopLevelComments.count == kids.count {
            commentsRemainingToLoad = false
        }
    }
    
    /// Load next top-level comment and the associated tree of replies (if exists), triggered by scrolling
    func loadMoreItems() {
        guard commentsRemainingToLoad,
              let story else { return }
                    
        if let focusedCommentViewModel { /// Comment-focused mode
            guard let kids = focusedCommentViewModel.comment.kids else {
                commentsRemainingToLoad = false
                return
            }
            for kid in kids {
                traverse(kid, parent: focusedCommentViewModel, indentation: focusedCommentViewModel.indendation + 1)
            }
            commentsRemainingToLoad = false
            
        } else {
            guard let kids = story.story.kids else { return }
            
            var nextKidToLoad: Int?
            for kid in kids {
                if loadedTopLevelComments.contains(kid) {
                    continue
                } else {
                    nextKidToLoad = kid
                    break
                }
            }
            
            if let nextKidToLoad {
                traverse(nextKidToLoad)
                loadedTopLevelComments.append(nextKidToLoad)

                let commentsLoaded = topLevelComments.reduce(0) { $0 + ($1.totalChildCount + 1) } /// Self (1) + number of children
                availableVoteLoader.evaluateShouldLoadNextCommentsPageAvailableVotes(numberOfCommentsLoaded: commentsLoaded, for: story)
            }
            
            if loadedTopLevelComments.count == kids.count {
                commentsRemainingToLoad = false
            }
        }
    }
    
    /// Pull-to-refresh action
    func refreshStory() async {
        Task { @MainActor in
            guard let story else { return }
            DispatchQueue.main.async { [weak self] in
                self?.comments.send([])
                self?.commentsExpanded.send([:])
            }
            
            topLevelComments.removeAll()
            loadedTopLevelComments.removeAll()
            
            let storyModel = try await apiManager.loadStory(id: story.id, cacheBehavior: .ignore).response
            self.story = StoryRowViewModel(story: storyModel)
            loadComments()
        }
    }
    
    /// When a comment is expanded or contracted, propagate the updated state iteratively to all children
    /// `hasPendingExpandedUpdate` is used to batch animate all updates, which significantly improves performance
    func updateExpanded(_ expanded: Dictionary<CommentViewModel, CommentExpandedState>, for comment: CommentViewModel, _ set: CommentExpandedState) {
        var mutableExpanded = expanded
        
        var queue = Array<CommentViewModel>()
        queue.append(contentsOf: comment.children)
        
        var remainingToAnimate = 5
        
        while(!queue.isEmpty) {
            let comment = queue.removeFirst()
            queue.insert(contentsOf: comment.children, at: 0)
                
            if set == .collapsed {
                mutableExpanded[comment] = .hidden
                if remainingToAnimate >= 0 {
                    comment.isAnimating = .collapsing
                    remainingToAnimate -= 1
                }
                
            } else {
                mutableExpanded[comment] = .expanded
                if remainingToAnimate >= 0 {
                    comment.isAnimating = .expanding
                    remainingToAnimate -= 1
                }
            }
        }
        
        /// Only one assignment to publisher to reduce redraws in SwiftUI
        hasPendingExpandedUpdate = true
        commentsExpanded.send(mutableExpanded)
    }
    
    func expandedUpdateComplete() {
        hasPendingExpandedUpdate = false
        
        comments.value
            .filter { $0.isAnimating != .none }
            .forEach { $0.isAnimating = .none }
    }
    
    func didTapVote(item: Votable, direction: HTMLAPIVoteDirection) {
        voteManager.vote(item: item, direction: direction) { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    // MARK: -
    /// Visit each leaf and create a view model, appending to the parent's `children` property
    private func traverse(_ rootCommentId: Int, parent: CommentViewModel? = nil, indentation: Int = 0) {
        apiManager.loadComment(id: rootCommentId)
            .flatMap { comment in
                comment.response.loadMarkdown()
            }
            .receive(on: DispatchQueue.global())
            .sink { completion in
                if case let .failure(error) = completion {
                    self.globalErrorStream.addError(error)
                    print(error)
                    DispatchQueue.main.async {
                        self.commentsLoaded.send(self.commentsLoaded.value + 1)
                    }
                }
            
        } receiveValue: { comment in
            let viewModel = CommentViewModel(comment: comment,
                                             indendation: indentation,
                                             parent: parent)
            
            if self.keychainWrapper.isLoggedIn,
               let vote = self.availableVotes[String(viewModel.id)] {
                viewModel.vote = vote
            }
               
            if let parent {
                parent.children.append(viewModel)
                self.incrementTotalChildCount(parent)
                
            } else {
                self.topLevelComments.append(viewModel)
                DispatchQueue.main.async {
                    self.currentlyLoadingComment.send(viewModel)
                }
            }
            
            DispatchQueue.main.async {
                /// Ensure that if a comment is loaded with a collapsed or hidden parent
                /// the newly loaded comment is also hidden
                /// This looks visually broken if not addressed explicitly
                var mutableCommentsExpanded = self.commentsExpanded.value
                
                if let parent,
                   (mutableCommentsExpanded[parent] == .collapsed ||
                    mutableCommentsExpanded[parent] == .hidden) {
                    mutableCommentsExpanded[viewModel] = .hidden
                    
                } else {
                    mutableCommentsExpanded[viewModel] = .expanded
                }
                
                self.commentsExpanded.send(mutableCommentsExpanded)
                self.commentsLoaded.send(self.commentsLoaded.value + 1)
            }
            
            if let kids = comment.kids {
                for kid in kids {
                    self.traverse(kid, parent: viewModel, indentation: indentation + 1)
                }
            }
        }
        .store(in: &disposeBag)
    }
    
    /// Once the comments are loaded, walk the tree and construct a flat representation
    /// for display as a list
    private func flatten() -> [CommentViewModel] {
        var queue = Array<CommentViewModel>()
        queue.append(contentsOf: topLevelComments)
        
        var flat = Array<CommentViewModel>()
        
        while(!queue.isEmpty) {
            let comment = queue.removeFirst()
            flat.append(comment)
            
            queue.insert(contentsOf: comment.children, at: 0)
        }
        
        return flat
    }
    
    /// Calculate the total number of child comments from the current tree node
    /// Called recursively until the whole tree is coveredd
    private func incrementTotalChildCount(_ root: CommentViewModel) {
        root.totalChildCount += 1
        if let parent = root.parent {
            incrementTotalChildCount(parent)
        }
    }
}

// MARK: - Comment Focused View
/// These functions are used when `StoryDetailInteractor` is initialized with an `itemId` that points to a `Comment`
/// signifying that we are comment-focused mode. This mode is triggered by tapping a comment on the `UserView` page.
extension StoryDetailInteractor {
    /// Recursively load all parent comments until we hit the root node - the `Story` object
    func traverse(_ rootComment: Comment) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = try await self.commentLoader.traverse(rootComment)
            
            if let story = result.story {
                self.story = StoryRowViewModel(story: story)
            }
            
            self.commentChain.insert(contentsOf: result.commentChain, at: 0)
            self.processComments()
        }
    }
    
    /// Flattens parent comments into an array and prepares them for presentation
    func processComments() {
        var parent: CommentViewModel?
        var mutableComments = self.comments.value
        var mutableCommentsExpanded = self.commentsExpanded.value
        
        for (i, comment) in commentChain.enumerated() {
            let model = CommentViewModel(comment: comment, indendation: i, parent: parent)
            self.currentlyLoadingComment.send(model)
            
            if let parent {
                parent.children.append(model)
            }
            
            mutableComments.append(model)
            
            if i == 0 {
                self.topLevelComments.append(model)
                self.loadedTopLevelComments.append(model.id)
                
            }
            if i == self.commentChain.count-1 {
                self.focusedCommentViewModel = model
            }
            
            mutableCommentsExpanded[model] = .expanded
            self.commentsLoaded.send(self.commentsLoaded.value + 1)
            
            parent = model
        }
        
        self.comments.send(mutableComments)
        self.commentsExpanded.send(mutableCommentsExpanded)
    }
}
