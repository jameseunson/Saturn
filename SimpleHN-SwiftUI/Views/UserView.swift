//
//  UserView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 11/1/2023.
//

import Foundation
import SwiftUI

struct UserView: View {
    @StateObject var interactor: UserInteractor
    @State var user: UserViewModel?
    
    @State var displayingSafariURL: URL?
    @State var items: [UserItemViewModel] = []
    
    /// Infinite scroll
    @State private var readyToLoadMore = false
    @State private var itemsRemainingToLoad = false
    
    @State var selectedCommentToShare: CommentViewModel?
    
    @State var selectedStoryToView: StoryRowViewModel?
    @State var selectedCommentToView: CommentViewModel?
    
    /// NSUserActivity - handoff
    static let userActivity = "com.JEON.SimpleHN.view-user"
    
    var body: some View {
        if let user {
            ScrollViewReader { reader in
                InfiniteScrollView(loader: interactor,
                                   readyToLoadMore: $readyToLoadMore,
                                   itemsRemainingToLoad: $itemsRemainingToLoad) {
                    
                    UserHeaderView(user: user, displayingSafariURL: $displayingSafariURL) { user in
                        // TODO:
                        
                    } onTapStoryId: { storyId in
                        // TODO:
                        
                    } onTapURL: { url in
                        displayingSafariURL = url
                    }
                    .id("top")
                    .padding()
                    
                    Divider()
                    
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
                                
                            } onToggleExpanded: { comment, expanded in
                                selectedCommentToView = comment
                                
                            } onTapURL: { url in
                                self.displayingSafariURL = url
                            }

                        case let .story(story):
                            StoryRowView(story: story,
                                         onTapArticleLink: { url in self.displayingSafariURL = url })
                                .onTapGesture {
                                    selectedStoryToView = story
                                }
                                .padding()
                        }
                        Divider()
                    }
                    if itemsRemainingToLoad {
                        ListLoadingView()
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
                if let selectedCommentToView {
                    StoryDetailView(interactor: StoryDetailInteractor(itemId: selectedCommentToView.id))
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
