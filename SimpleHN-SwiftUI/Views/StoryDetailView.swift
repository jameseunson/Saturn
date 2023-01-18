//
//  StoryDetailView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 8/1/2023.
//

import Foundation
import SwiftUI

struct StoryDetailView: View {
    @State var story: Story?
    
    @StateObject var interactor: StoryDetailInteractor
    @State private var isShowingSafariView = false
    @State private var commentsExpanded: Dictionary<CommentViewModel, CommentExpandedState> = [:]
    
    @State var isShareVisible: Bool = false
    @State var selectedUser: String? = nil
    
    /// Infinite scroll
    @State private var readyToLoadMore = false
    @State private var commentsRemainingToLoad = false
    
    var body: some View {
        ZStack {
            if let story {
                InfiniteScrollView(loader: interactor,
                                   readyToLoadMore: $readyToLoadMore,
                                   itemsRemainingToLoad: $commentsRemainingToLoad) {
                    
                    StoryRowView(story: StoryRowViewModel(story: story))
                        .padding(EdgeInsets(top: 0, leading: 10, bottom: 20, trailing: 10))
                        .onTapGesture {
                            isShowingSafariView = true
                        }
                    Divider()
                    
                    if interactor.comments.count == 0 {
                        ListLoadingView()
                            .listRowSeparator(.hidden)
                            .padding(10)
                        
                    } else {
                        ForEach(interactor.comments) { comment in
                            CommentView(expanded: binding(for: comment), comment: comment) { comment in
                                print("test")
                                
                            } onTapUser: { user in
                                selectedUser = user
                                
                            } onToggleExpanded: { comment, expanded in
                                self.interactor.updateExpanded(commentsExpanded, for: comment, expanded)
                            }
                            .padding(10)
                        }
                        if commentsRemainingToLoad {
                            ListLoadingView()
                        }
                    }
                }
                .refreshable {
                    await interactor.refreshComments()
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
        .onReceive(interactor.$story, perform: { output in
            self.story = output
        })
        .navigationDestination(isPresented: displayingUserBinding()) {
            if let selectedUser {
                UserView(interactor: UserInteractor(username: selectedUser))
                    .navigationTitle(selectedUser)
            } else {
                EmptyView()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    isShareVisible = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $isShareVisible, content: {
            if let url = story?.url {
                let sheet = ActivityViewController(itemsToShare: [url])
                    .ignoresSafeArea()
                if #available(iOS 16, *) {
                    sheet.presentationDetents([.medium])
                } else {
                    sheet
                }
            }
        })
        .sheet(isPresented: $isShowingSafariView) {
            if let url = story?.url {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .onReceive(interactor.$commentsExpanded) { output in
            commentsExpanded = output
        }
    }

    /// Binding that creates CommentExpandedState state for every individual comment
    /// Passed to CommentView
    func binding(for comment: CommentViewModel) -> Binding<CommentExpandedState> {
        return Binding {
            return self.commentsExpanded[comment] ?? .expanded
        } set: {
            self.commentsExpanded[comment] = $0
        }
    }
    
    func displayingUserBinding() -> Binding<Bool> {
        Binding {
            selectedUser != nil
        } set: { value in
            if !value { selectedUser = nil }
        }
    }
}
