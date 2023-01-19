//
//  UserView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 11/1/2023.
//

import Foundation
import SwiftUI

enum UserItemViewModel: Identifiable, Equatable {
    var id: Int {
        switch self {
        case let .comment(comment):
            return comment.id
        case let .story(story):
            return story.id
        }
    }
    
    case comment(CommentViewModel)
    case story(StoryRowViewModel)
}

struct UserView: View {
    @StateObject var interactor: UserInteractor
    @State var user: UserViewModel?
    
    @State var displayingSafariURL: URL?
    @State var items: [UserItemViewModel] = []
    
    /// Infinite scroll
    @State private var readyToLoadMore = false
    @State private var itemsRemainingToLoad = false
    
    @State var selectedCommentToShare: CommentViewModel?
    
    var body: some View {
        if let user {
            InfiniteScrollView(loader: interactor,
                               readyToLoadMore: $readyToLoadMore,
                               itemsRemainingToLoad: $itemsRemainingToLoad) {
                
                UserHeaderView(user: user, displayingSafariURL: $displayingSafariURL)
                    .padding([.leading, .trailing])

                Divider()
                
                ForEach(items) { item in
                    VStack {
                        switch item {
                        case let .comment(comment):
                            CommentView(expanded: .constant(.expanded), comment: comment) { comment in
                                selectedCommentToShare = comment
                            } onToggleExpanded: { comment, expanded in
                                print(comment)
                            }
                            .padding([.trailing, .leading, .bottom])

                        case let .story(story):
                            Divider()
                            StoryRowView(story: story)
                                .padding([.trailing, .leading, .bottom])
                        }
                    }
                }
                if itemsRemainingToLoad {
                    ListLoadingView()
                }
            }
            .sheet(isPresented: displayingSafariViewBinding()) {
                if let displayingSafariURL {
                    SafariView(url: displayingSafariURL)
                        .ignoresSafeArea()
                }
            }
            .sheet(isPresented: isShareVisible(), content: {
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
    
    func displayingSafariViewBinding() -> Binding<Bool> {
        Binding {
            displayingSafariURL != nil
        } set: { value in
            if !value { displayingSafariURL = nil }
        }
    }
    
    func isShareVisible() -> Binding<Bool> {
        Binding {
            selectedCommentToShare != nil
        } set: { value in
            if !value { selectedCommentToShare = nil }
        }
    }
}
