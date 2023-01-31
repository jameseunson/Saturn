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
    @State private var comments: Array<CommentViewModel> = []
    @State private var commentsExpanded: Dictionary<CommentViewModel, CommentExpandedState> = [:]
    
    @State var selectedShareItem: StoryDetailShareItem?
    @State var selectedUser: String?
    @State var displayingInternalStoryId: Int?
    @State var selectedComment: CommentViewModel?
    @State var displayingSafariURL: URL?
    
    /// Infinite scroll
    @State private var readyToLoadMore = false
    @State private var commentsRemainingToLoad = false
    
    /// NSUserActivity - handoff
    static let userActivity = "com.JEON.SimpleHN.read-story"
    
    var body: some View {
        ZStack {
            if let story = interactor.story {
                InfiniteScrollView(loader: interactor,
                                   readyToLoadMore: $readyToLoadMore,
                                   itemsRemainingToLoad: $commentsRemainingToLoad) {
                    
                    StoryRowView(story: StoryRowViewModel(story: story))
                        .padding()
                        .onTapGesture {
                            if story.url != nil {
                                displayingSafariURL = story.url
                            }
                        }
                    
                    Divider()
                    
                    if let text = story.text {
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
                    
                    if story.hasComments() {
                        if comments.count == 0 {
                            ListLoadingView()
                                .listRowSeparator(.hidden)
                            
                        } else {
                            ForEach(comments, id: \.self) { comment in
                                CommentView(expanded: binding(for: comment), comment: comment) { comment in
                                    selectedComment = comment
                                    
                                } onTapUser: { user in
                                    selectedUser = user
                                    
                                } onToggleExpanded: { comment, expanded in
                                    self.interactor.updateExpanded(commentsExpanded, for: comment, expanded)
                                    
                                } onTapStoryId: { storyId in
                                    self.displayingInternalStoryId = storyId
                                }
                            }
                            
                            if interactor.commentsRemainingToLoad {
                                ListLoadingView()
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
        .onReceive(interactor.commentsDebounced) { output in
            comments = output
        }
        .onReceive(interactor.commentsExpandedDebounced) { output in
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
        .sheet(isPresented: displayingSafariViewBinding()) {
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
    }
    
    func displayingSafariViewBinding() -> Binding<Bool> {
        Binding {
            displayingSafariURL != nil
        } set: { value in
            if !value { displayingSafariURL = nil }
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
}

struct StoryDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            StoryDetailView(interactor: StoryDetailInteractor(story: Story.fakeStoryWithNoComments(), comments: [])) // CommentViewModel.fakeComment()
                .navigationTitle("Story")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
