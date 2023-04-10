//
//  UserView.swift
//  Saturn
//
//  Created by James Eunson on 11/1/2023.
//

import Foundation
import SwiftUI

struct UserView: View {
    @StateObject var interactor: UserInteractor
    @State var user: UserViewModel?
    
    @State var items: [UserItemViewModel] = []
    @State var contexts: [Int: CommentLoaderContainer] = [:]
    
    /// Infinite scroll
    @State private var readyToLoadMore = false
    @State private var itemsRemainingToLoad = false
    
    /// Navigation
    @State var displayingSafariURL: URL?
    @State var selectedCommentToShare: CommentViewModel?
    @State var selectedStoryToView: StoryRowViewModel?
    @State var selectedCommentToView: CommentViewModel?
    @State var displayingInternalStoryId: Int?
    
    /// NSUserActivity - handoff
    static let userActivity = "com.JEON.Saturn.view-user"
    
    var body: some View {
        if let user {
            ScrollViewReader { reader in
                InfiniteScrollView(loader: interactor,
                                   readyToLoadMore: $readyToLoadMore,
                                   itemsRemainingToLoad: $itemsRemainingToLoad) {
                    
                    UserHeaderView(user: user, displayingSafariURL: $displayingSafariURL) { user in
                        // TODO:
                        
                    } onTapStoryId: { storyId in
                        displayingInternalStoryId = storyId
                        
                    } onTapURL: { url in
                        displayingSafariURL = url
                    }
                    .id("top")
                    .padding()
                    
                    Divider()
                    
                    if items.count == 0 {
                        HStack {
                            Spacer()
                            Text("No submissions yet...")
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(height: UIScreen.main.bounds.height - 250)
                        .listRowSeparator(.hidden)
                        
                    } else {
                        ForEach(items) { item in
                            switch item {
                            case let .comment(comment):
                                CommentView(expanded: .constant(.expanded),
                                            comment: comment,
                                            displaysStory: true) { comment in
                                    selectedCommentToShare = comment
                                    
                                } onTapUser: { _ in
                                    withAnimation {
                                        reader.scrollTo("top")
                                    }
                                    
                                } onToggleExpanded: { comment, expanded, commentOnScreen in
                                    selectedCommentToView = comment
                                    
                                } onTapStoryId: { storyId in
                                    displayingInternalStoryId = storyId
                                    
                                } onTapURL: { url in
                                    self.displayingSafariURL = url
                                }
                                VStack(alignment: .leading) {
                                    if let context = contexts[comment.id],
                                       let story = context.story {
                                        StoryRowView(story: StoryRowViewModel(story: story),
                                                     onTapArticleLink: { url in self.displayingSafariURL = url },
                                                     context: .user)
                                            .padding([.top, .bottom], 10)
                                            .onTapGesture {
                                                selectedStoryToView = StoryRowViewModel(story: story)
                                            }
                                    } else {
                                        ProgressView()
                                            .padding()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .background {
                                    RoundedRectangle(cornerRadius: 8)
                                        .foregroundColor( Color(UIColor.systemGray6) )
                                }
                                .padding(10)
                                .padding(.bottom, 20)

                            case let .story(story):
                                StoryRowView(story: story,
                                             onTapArticleLink: { url in self.displayingSafariURL = url })
                                    .onTapGesture {
                                        selectedStoryToView = story
                                    }
                                    .padding([.top, .bottom], 10)
                            }
                            Divider()
                        }
                        if itemsRemainingToLoad {
                            ListLoadingView()
                        }
                    }
                }
            }
            .sheet(isPresented: createBoolBinding(from: $displayingSafariURL)) {
                if let displayingSafariURL {
                    SafariView(url: displayingSafariURL)
                        .ignoresSafeArea()
                }
            }
            .sheet(isPresented: createBoolBinding(from: $selectedCommentToShare), content: {
                if let url = selectedCommentToShare?.comment.url {
                    let sheet = ActivityViewController(itemsToShare: [url])
                        .ignoresSafeArea()
                    sheet.presentationDetents([.medium])
                }
            })
            .onReceive(interactor.$items) { output in
                items = output
            }
            .onReceive(interactor.$readyToLoadMore, perform: { output in
                readyToLoadMore = output
            })
            .onReceive(interactor.$itemsRemainingToLoad, perform: { output in
                itemsRemainingToLoad = output
            })
            .onReceive(interactor.commentContexts, perform: { output in
                withAnimation {
                    contexts = output
                }
            })
            .refreshable {
                await interactor.refreshUser()
            }
            .navigationDestination(isPresented: createBoolBinding(from: $selectedStoryToView)) {
                if let selectedStoryToView {
                    StoryDetailView(interactor: StoryDetailInteractor(itemId: selectedStoryToView.id))
                        .navigationTitle(selectedStoryToView.title)
                } else {
                    EmptyView()
                }
            }
            .navigationDestination(isPresented: createBoolBinding(from: $selectedCommentToView)) {
                if let selectedCommentToView,
                   let thread = contexts[selectedCommentToView.id] {
                    StoryDetailView(interactor: StoryDetailInteractor(comment: selectedCommentToView, thread: thread))
                } else {
                    EmptyView()
                }
            }
            .navigationDestination(isPresented: createBoolBinding(from: $displayingInternalStoryId)) {
                if let displayingInternalStoryId {
                    StoryDetailView(interactor: StoryDetailInteractor(itemId: displayingInternalStoryId))
                } else {
                    EmptyView()
                }
            }
            .userActivity(UserView.userActivity) { activity in
                if let user = interactor.user,
                   let url = URL(string: "https://news.ycombinator.com/user?id=\(user.id)") {
                    activity.webpageURL = url
                    activity.becomeCurrent()
                }
            }

        } else {
            LoadingView()
            .onAppear {
                interactor.activate()
            }
            .onReceive(interactor.$user) { output in
                if let output {
                    self.user = UserViewModel(user: output)
                }
            }
            .onReceive(interactor.$items) { output in
                self.items = output
            }
        }
    }
}
