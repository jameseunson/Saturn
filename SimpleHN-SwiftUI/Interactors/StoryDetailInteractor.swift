//
//  StoryDetailInteractor.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 9/1/2023.
//

import Combine
import Foundation
import SwiftUI
import UIKit

enum CommentExpandedState {
    case expanded
    case collapsed
    case hidden
}

final class StoryDetailInteractor: Interactor, InfiniteScrollViewLoading {
    // MARK: - Public
    @Published var readyToLoadMore: Bool = false
    @Published var commentsRemainingToLoad: Bool = true
    @Published var story: Story?
    
    var comments = CurrentValueSubject<Array<CommentViewModel>, Never>([])
    var commentsDebounced: AnyPublisher<Array<CommentViewModel>, Never> = Empty().eraseToAnyPublisher()
    
    var commentsExpanded = CurrentValueSubject<Dictionary<CommentViewModel, CommentExpandedState>, Never>([:])
    var commentsExpandedDebounced: AnyPublisher<Dictionary<CommentViewModel, CommentExpandedState>, Never> = Empty().eraseToAnyPublisher()
    
    // MARK: - Private
    private var commentsLoaded = CurrentValueSubject<Int, Never>(0)
    private var currentlyLoadingComment = CurrentValueSubject<CommentViewModel?, Never>(nil)
    
    private var storyId: Int?
    private let apiManager = APIManager()
    
    private var topLevelComments = [CommentViewModel]()
    private var loadedTopLevelComments = [Int]()
    
    #if DEBUG
    private var displayingSwiftUIPreview = false
    #endif
    
    /// Entry from StoriesView, we already have a `Story` object
    init(story: Story, comments: [CommentViewModel] = []) {
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
    /// where we don't yet have a full `Story` object, and it must be loaded as part of the interactor startup
    init(storyId: Int) {
        self.storyId = storyId
    }
    
    override func didBecomeActive() {
        #if DEBUG
        if displayingSwiftUIPreview {
            return
        }
        #endif
        
        commentsDebounced = comments.debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
        commentsExpandedDebounced = commentsExpanded.debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
        
        loadComments()
        
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
        
        if let storyId {
            apiManager.loadStory(id: storyId)
                .sink { completion in
                    if case let .failure(error) = completion {
                        print(error)
                    }
                    
                } receiveValue: { story in
                    self.story = story
                    self.loadComments()
                }
                .store(in: &disposeBag)
        }
    }
    
    func loadComments() {
        guard let kids = story?.kids,
              let firstKid = kids.first else { return }
        
        traverse(firstKid)
        loadedTopLevelComments.append(firstKid)
        
        if loadedTopLevelComments.count == kids.count {
            commentsRemainingToLoad = false
        }
    }
    
    func loadMoreItems() {
        guard let kids = story?.kids else { return }
        
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
        }
        if loadedTopLevelComments.count == kids.count {
            commentsRemainingToLoad = false
        }
    }
    
    func refreshComments() async {
        Task {
            DispatchQueue.main.async { [weak self] in
                self?.comments.send([])
                self?.commentsExpanded.send([:])
            }
            
            topLevelComments.removeAll()
            loadedTopLevelComments.removeAll()
            
            loadComments()
        }
    }
    
    func updateExpanded(_ expanded: Dictionary<CommentViewModel, CommentExpandedState>, for comment: CommentViewModel, _ set: CommentExpandedState) {
        var mutableExpanded = expanded
        
        var queue = Array<CommentViewModel>()
        queue.append(contentsOf: comment.children)
        
        while(!queue.isEmpty) {
            let comment = queue.removeFirst()
            queue.insert(contentsOf: comment.children, at: 0)
            
            if set == .collapsed {
                mutableExpanded[comment] = .hidden
            } else {
                mutableExpanded[comment] = .expanded
            }
        }
        
        /// Only one assignment to publisher to reduce redraws in SwiftUI
        commentsExpanded.send(mutableExpanded)
    }
    
    // MARK: -
    /// Visit each leaf and create a view model, appending to the parent's `children` property
    private func traverse(_ rootCommentId: Int, parent: CommentViewModel? = nil, indentation: Int = 0) {
        apiManager.loadComment(id: rootCommentId)
            .flatMap { comment in
                comment.loadMarkdown()
            }
            .receive(on: DispatchQueue.global())
            .sink { completion in
                if case let .failure(error) = completion {
                    print(error)
                    DispatchQueue.main.async {
                        self.commentsLoaded.send(self.commentsLoaded.value + 1)
                    }
                }
            
        } receiveValue: { comment in
            let viewModel = CommentViewModel(comment: comment,
                                             indendation: indentation,
                                             parent: parent)
            if let parent {
                parent.children.append(viewModel)
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
}
