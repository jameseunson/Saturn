//
//  StoryDetailView.swift
//  Saturn
//
//  Created by James Eunson on 8/1/2023.
//

import Foundation
import SwiftUI
import Factory

struct StoryDetailView: View {
    @Injected(\.keychainWrapper) private var keychainWrapper
    
    @StateObject var interactor: StoryDetailInteractor
    @State private var comments: Array<CommentViewModel> = []
    @State private var commentsExpanded: Dictionary<CommentViewModel, CommentExpandedState> = [:]
    
    /// Navigation
    @State var selectedShareItem: StoryDetailShareItem?
    @State var selectedUser: String?
    @State var displayingInternalStoryId: Int?
    @State var selectedComment: CommentViewModel?
    @State var displayingSafariURL: URL?
    @State var displayingConfirmSheetForStory: StoryRowViewModel?
    
    /// Infinite scroll
    @State private var readyToLoadMore = false
    @State private var commentsRemainingToLoad = false
    
    /// Comment focused view
    @State var displayFullComments = false
    @State var didScrollToFocusedComment = false
    
    var body: some View {
        ZStack {
            if let story = interactor.story {
                contentView(for: story)
                
                if interactor.focusedCommentViewModel != nil {
                    ViewAllCommentsButton(displayFullComments: $displayFullComments)
                }
                
            } else {
                LoadingView()
            }
        }
        .onAppear {
            interactor.activate()
        }
        .onReceive(interactor.$readyToLoadMore, perform: { output in
            readyToLoadMore = output
        })
        .onReceive(interactor.$commentsRemainingToLoad, perform: { output in
            commentsRemainingToLoad = output
        })
        .onReceive(interactor.commentsDebounced) { output in
            comments = output
        }
        .onReceive(interactor.commentsExpanded) { output in
            /// Handle expand/contract immediately, instead of using the debounce stream
            /// Ensures expand/contract is as responsive as possible
            if !interactor.hasPendingExpandedUpdate {
                return
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                commentsExpanded = output
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(350)) {
                interactor.expandedUpdateComplete()
            }
        }
        .onReceive(interactor.commentsExpandedDebounced) { output in
            if interactor.hasPendingExpandedUpdate {
                return
            }
            /// Initial setup should not be animated
            if commentsExpanded.isEmpty {
                commentsExpanded = output
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    commentsExpanded = output
                }
            }
        }
        .modifier(CommentNavigationModifier(selectedShareItem: $selectedShareItem,
                                            selectedUser: $selectedUser,
                                            displayingInternalStoryId: $displayingInternalStoryId,
                                            selectedComment: $selectedComment)
        )
        .modifier(StoryContextSheetModifier(displayingConfirmSheetForStory: $displayingConfirmSheetForStory,
                                            selectedShareItem: $selectedShareItem,
                                            selectedUser: $selectedUser,
                                            onTapVote: { direction in
            if let story = displayingConfirmSheetForStory {
                self.interactor.didTapVote(item: story, direction: direction)
            }
        }))
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    if let story = interactor.story {
                        selectedShareItem = .story(story)
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: createBoolBinding(from: $displayingSafariURL)) {
            if let displayingSafariURL {
                SafariView(url: displayingSafariURL)
                    .ignoresSafeArea()
            }
        }
        .userActivity(StoryDetailView.userActivity) { activity in
            if let story = interactor.story,
               let url = URL(string: "https://news.ycombinator.com/item?id=\(story.id)") {
                activity.webpageURL = url
                activity.becomeCurrent()
            }
        }
        .navigationDestination(isPresented: $displayFullComments) {
            if displayFullComments {
                if let story = interactor.story {
                    StoryDetailView(interactor: StoryDetailInteractor(itemId: story.id))
                        .navigationTitle(story.title)
                } else {
                    EmptyView()
                }
            }
        }
    }
    
    func contentView(for story: StoryRowViewModel) -> some View {
        return ScrollViewReader { reader in
            InfiniteScrollView(loader: interactor,
                               readyToLoadMore: $readyToLoadMore,
                               itemsRemainingToLoad: $commentsRemainingToLoad) {
                
                StoryRowView(story: story,
                             image: bindingForStoryImage(),
                             onTapArticleLink: { url in self.displayingSafariURL = url },
                             onTapUser: { user in self.selectedUser = user },
                             onTapVote: { direction in self.interactor.didTapVote(item: story, direction: direction) },
                             onTapSheet: { story in self.displayingConfirmSheetForStory = story },
                             context: .storyDetail)
                    .padding(.top)
                    .if(!keychainWrapper.isLoggedIn, transform: { view in
                        view.padding(.bottom)
                    })
                    .onTapGesture {
                        if story.url != nil {
                            displayingSafariURL = story.url
                        }
                    }
                
                if let text = story.text {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(text)
                            .modifier(TextLinkHandlerModifier(onTapUser: { user in
                                selectedUser = user
                                
                            }, onTapStoryId: { storyId in
                                displayingInternalStoryId = storyId
                                
                            }, onTapURL: { url in
                                displayingSafariURL = url
                            }))
                            .padding(10)
                        Divider()
                    }
                }
                
                if story.hasComments() {
                    if comments.count == 0 {
                        ListLoadingView()
                            .listRowSeparator(.hidden)

                    } else {
                        ForEach(comments, id: \.self) { comment in
                            if comment.isAnimating != .none || self.commentsExpanded[comment] != .hidden {
                                CommentView(expanded: binding(for: comment),
                                            comment: comment,
                                            isHighlighted: interactor.focusedCommentViewModel == comment) { comment in
                                    selectedComment = comment

                                } onTapUser: { user in
                                    selectedUser = user

                                } onToggleExpanded: { comment, expanded, commentOnScreen in
                                    if expanded == .collapsed,
                                       !commentOnScreen {
                                        withAnimation {
                                            reader.scrollTo(comment.id, anchor: .top)
                                        }
                                    }
                                    self.interactor.updateExpanded(commentsExpanded, for: comment, expanded)

                                } onTapStoryId: { storyId in
                                    self.displayingInternalStoryId = storyId

                                } onTapURL: { url in
                                    displayingSafariURL = url

                                } onTapVote: { direction in
                                    self.interactor.didTapVote(item: comment, direction: direction)
                                    
                                } onTapShare: { comment in
                                    selectedShareItem = .comment(comment)
                                }
                                .id(comment.id)
                                .onAppear {
                                    if interactor.focusedCommentViewModel != nil,
                                       comment == comments.first,
                                       let lastCommentId = comments.last?.id,
                                       !didScrollToFocusedComment {
                                        didScrollToFocusedComment = true
                                        withAnimation {
                                            reader.scrollTo(lastCommentId)
                                        }
                                    }
                                }
                                .zIndex(10000.0 - Double(self.comments.firstIndex(of: comment) ?? 0))
                            }
                        }

                        if interactor.commentsRemainingToLoad {
                            ListLoadingView()
                        }

                        if interactor.focusedCommentViewModel != nil {
                            Spacer()
                                .padding([.bottom], 100)
                        }
                    }

                } else {
                    HStack {
                        Spacer()
                        Text("No comments yet...")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(height: UIScreen.main.bounds.height - 250)
                    .listRowSeparator(.hidden)
                }
            }
           .refreshable {
               await interactor.refreshStory()
           }
        }
    }
    
    /// Binding that creates CommentExpandedState state for every individual comment
    /// Passed to CommentView
    func binding(for comment: CommentViewModel) -> Binding<CommentExpandedState> {
        return Binding {
            return self.commentsExpanded[comment] ?? .hidden
        } set: {
            self.commentsExpanded[comment] = $0
        }
    }
    
    func bindingForStoryImage() -> Binding<Image?> {
        Binding { return interactor.storyFavIcon } set: { _ in }
    }
    
    /// NSUserActivity - handoff
    static let userActivity = "au.jameseunson.Saturn.read-story"
}

struct StoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            if let story = Story.fakeStoryWithNoComments() {
                StoryDetailView(interactor: StoryDetailInteractor(story: StoryRowViewModel(story: story), comments: [])) // CommentViewModel.fakeComment()
                    .navigationTitle("Story")
                    .navigationBarTitleDisplayMode(.inline)
            } else {
                EmptyView()
            }
        }
    }
}
