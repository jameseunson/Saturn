//
//  StoryDetailView.swift
//  SimpleHN-SwiftUI
//
//  Created by James Eunson on 8/1/2023.
//

import Foundation
import SwiftUI

struct StoryDetailView: View {
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
            if let story = interactor.story {
                GeometryReader { reader in
                    InfiniteScrollView(loader: interactor,
                                       readyToLoadMore: $readyToLoadMore,
                                       itemsRemainingToLoad: $commentsRemainingToLoad) {
                        
                        StoryRowView(story: StoryRowViewModel(story: story))
                            .padding(.bottom, 10)
                            .onTapGesture {
                                if story.url != nil {
                                    isShowingSafariView = true
                                }
                            }
                        
                        if let text = story.text {
                            Text(text)
                                .padding(10)
                        }
                        
                        if story.hasComments() {
                            if interactor.comments.count == 0 {
                                ListLoadingView()
                                    .listRowSeparator(.hidden)
                                
                            } else {
                                ForEach(interactor.displayComments) { comment in
                                    CommentView(expanded: binding(for: comment), comment: comment) { comment in
                                        selectedComment = comment
                                        
                                    } onTapUser: { user in
                                        selectedUser = user
                                        
                                    } onToggleExpanded: { comment, expanded in
                                        self.interactor.updateExpanded(commentsExpanded, for: comment, expanded)
                                        
                                    } onTapStoryId: { storyId in
                                        self.displayingInternalStoryId = storyId
                                    }
                                    .contextMenu {
                                        Button(action: { selectedComment = comment }, label:
                                        {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        })
                                        Button(action: { selectedUser = comment.by }, label:
                                        {
                                            Label(comment.by, systemImage: "person.circle")
                                        })
                                    }
                                }
                                
                                if interactor.commentsRemainingToLoad {
                                    ListLoadingView()
                                }
                            }
                        } else {
                            Text("No comments yet...")
                                .foregroundColor(.gray)
                                .frame(height: max(reader.size.height - 150, 0))
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
        .onReceive(interactor.$commentsExpanded) { output in
            commentsExpanded = output
        }
        .modifier(CommentNavigationModifier(selectedShareItem: $selectedShareItem,
                                            selectedUser: $selectedUser,
                                            displayingInternalStoryId: $displayingInternalStoryId,
                                            selectedComment: $selectedComment))
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
        .sheet(isPresented: $isShowingSafariView) {
            if let url = interactor.story?.url {
                SafariView(url: url)
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
        #if DEBUG
        NavigationStack {
            StoryDetailView(interactor: StoryDetailInteractor(story: Story.fakeStory(), comments: [CommentViewModel.fakeComment()]))
                .navigationTitle("Story")
                .navigationBarTitleDisplayMode(.inline)
        }
        #else
        EmptyView()
        #endif
    }
}
