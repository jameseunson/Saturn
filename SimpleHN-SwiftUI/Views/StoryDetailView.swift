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
    
    @State var selectedShareItem: StoryDetailShareItem?
    @State var selectedUser: String?
    @State var displayingInternalStoryId: Int?
    @State var selectedComment: CommentViewModel?
    
    /// Infinite scroll
    @State private var readyToLoadMore = false
    @State private var commentsRemainingToLoad = false
    
    /// NSUserActivity - handoff
    static let userActivity = "com.JEON.SimpleHN.read-story"
    
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
                                selectedComment = comment
                                
                            } onTapUser: { user in
                                selectedUser = user
                                
                            } onToggleExpanded: { comment, expanded in
                                self.interactor.updateExpanded(commentsExpanded, for: comment, expanded)
                                
                            } onTapStoryId: { storyId in
                                self.displayingInternalStoryId = storyId
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
            UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColor(named: "AccentColor")
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
        .navigationDestination(isPresented: displayingInternalStoryIdBinding()) {
            if let displayingInternalStoryId {
                StoryDetailView(interactor: StoryDetailInteractor(storyId: displayingInternalStoryId))
            } else {
                EmptyView()
            }
        }
        .confirmationDialog("User", isPresented: displayingCommentSheet(), actions: {
            if let selectedComment {
                Button(selectedComment.by) {
                    selectedUser = selectedComment.by
                }
                Button("Share Comment") {
                    selectedShareItem = .comment(selectedComment)
                }
            }
        })
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    if let story {
                        selectedShareItem = .story(story)
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: isShareVisible(), content: {
            if let url = selectedShareItem?.url {
                let sheet = ActivityViewController(itemsToShare: [url])
                    .ignoresSafeArea()
                sheet.presentationDetents([.medium])
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
        .userActivity(StoryDetailView.userActivity) { activity in
            if let story,
               let url = URL(string: "https://news.ycombinator.com/item?id=\(story.id)") {
                activity.webpageURL = url
                activity.becomeCurrent()
            }
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
    
    func displayingInternalStoryIdBinding() -> Binding<Bool> {
        Binding {
            displayingInternalStoryId != nil
        } set: { value in
            if !value { displayingInternalStoryId = nil }
        }
    }
    
    func displayingCommentSheet() -> Binding<Bool> {
        Binding {
            selectedComment != nil
        } set: { value in
            if !value { selectedComment = nil }
        }
    }
    
    func isShareVisible() -> Binding<Bool> {
        Binding {
            selectedShareItem != nil
        } set: { value in
            if !value { selectedShareItem = nil }
        }
    }
}
