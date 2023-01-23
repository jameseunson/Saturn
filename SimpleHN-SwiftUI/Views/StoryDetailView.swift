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
                GeometryReader { reader in
                    InfiniteScrollView(loader: interactor,
                                       readyToLoadMore: $readyToLoadMore,
                                       itemsRemainingToLoad: $commentsRemainingToLoad) {
                        
                        StoryRowView(story: StoryRowViewModel(story: story))
                            .padding(EdgeInsets(top: 0, leading: 10, bottom: 20, trailing: 10))
                            .onTapGesture {
                                if story.url != nil {
                                    isShowingSafariView = true
                                }
                            }
                        Divider()
                        
                        if let text = story.text {
                            Text(text)
                                .padding(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 10))
                        }
                        
                        if story.hasComments() {
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
                        } else {
                            Text("No comments yet...")
                                .foregroundColor(.gray)
                                .frame(height: max(reader.size.height - 100, 0))
                        }
                    }
                   .refreshable {
                       await interactor.refreshComments()
                   }
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
        .modifier(CommentNavigationModifier(selectedShareItem: $selectedShareItem,
                                            selectedUser: $selectedUser,
                                            displayingInternalStoryId: $displayingInternalStoryId,
                                            selectedComment: $selectedComment))
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
}

struct StoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            StoryDetailView(interactor: StoryDetailInteractor(story: Story.fakeStory(), comments: [CommentViewModel.fakeComment()]))
                .navigationTitle("Story")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
